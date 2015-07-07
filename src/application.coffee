# Module dependencies
express = require("express")
bodyParser = require("body-parser")
compression = require("compression")
mysql = require("mysql")
yaml = require("js-yaml")
fs = require("fs")
u = require("underscore")

# This class implements the initialization and termination logic of Sqlcached.
# It provides also a way to know what should be done when an uncaught exception
# bubbles up.
#
# @example How to use
#   app = new Application(command_line_arguments, logger)
#   app.init() // run
#   app.term() // terminate
#   app.getErrorHandler(error) // returns an object like
#     // { reinit: (true|false), reinitOptions: {} }
#     // so when reinit is true the application should be reinitialized with
#     // the specified reinitOptions to continue
#
class Application

  constructor: (@argv, @logger) ->


  init: (options) ->
    logger = @logger
    @mysqlConnectionPool = @_getMysqlConnectionPool()

    # Application modules
    @cacheStrategy = require("./cache-strategy").build()
    database = require("./database").getDatabase(@mysqlConnectionPool,
      @cacheStrategy)
    queryTemplates = require("./query-templates").getSet()
    manager = require("./manager").getApplicationManager(logger,
      queryTemplates, database)

    # General error handler
    errorHandler = (err, req, res, next) ->
      logger.error(err, "Express app error handler called")
      res.status(500).type("json").send(
        JSON.stringify( error: err.toString() ))

    # Init Express application
    app = express()
    app.use(bodyParser.urlencoded(extended: false, limit: "10mb"))
    app.use(bodyParser.json(limit: "10mb"))
    app.use(compression())
    app.use(errorHandler) # must be the last middleware registered

    httpCallback = (err, entity, res, successCode) ->
      res.format
        json: ->
          if err
            res = res.status(err.status)
            if u.isString(err)
              res.send(err)
            else
              res.send(JSON.stringify(err))
          else
            res = res.status(successCode)
            if u.isString(entity)
              res.send(entity)
            else
              res.send(JSON.stringify(entity))

    # routes
    app.get "/queries", (request, response) ->
      manager.indexQueries (err, value) ->
        httpCallback(err, value, response, 200)

    app.post "/queries", (request, response) ->
      id = request.body["id"]
      query = request.body["query_template"]
      cache = request.body["cache"]
      manager.createQuery id, query, cache, (err, value) ->
        httpCallback(err, value, response, 201)

    app.delete "/queries/:id", (request, response) ->
      manager.deleteQuery request.params.id, (err, reply) ->
        httpCallback(err, reply, response, 200)

    app.get "/data/:query_id", (request, response) ->
      queryId = request.params.query_id
      queryParams = request.query.query_params
      manager.getData queryId, queryParams, (err, reply) ->
        httpCallback(err, reply, response, 200)

    app.delete "/data/:query_id/cache", (request, response) ->
      queryId = request.params.query_id
      queryParams = request.query.query_params
      manager.deleteDataCache queryId, queryParams, (err, reply) ->
        httpCallback(err, reply, response, 200)

    app.post "/data-batch", (request, response) ->
      if batchData = request.body["batch"]
        manager.getDataBatch batchData, (err, reply) ->
          httpCallback(err, reply, response, 200)
      else if tree = request.body["tree"]
        rootParams = request.body["root_parameters"] || []
        attachments = request.body["attachments"]
        manager.getDataTree tree, rootParams, attachments, (err, reply) ->
          httpCallback(err, reply, response, 200)
      else
        httpCallback({ status: 422, message: "Invalid request body" }, undefined,
          response, undefined)

    app.post "/resultset-attachments", (request, response) ->
      if (resultset = request.body["resultset"])? &&
          (attachments = request.body["attachments"])?
        manager.storeAttachments resultset, attachments, (err, reply) ->
          httpCallback(err, reply, response, 201)
      else
        httpCallback({ status: 422, message: "Invalid request body" }, undefined,
          response, undefined)


    # Start the http server
    @server = app.listen @argv.port || 8081, =>
      host = @server.address().address
      port = @server.address().port
      @logger.info("Server listening at http://%s:%s", host, port)
    # end of init


  term: ->
    logger = @logger
    logger.info "application.term called, shutting down..."
    if @server?
      @server.close (error) ->
        logger.error(error, "error while closing the server") if error?
    if @mysqlConnectionPool?
      @mysqlConnectionPool.end (error) ->
        if error?
          logger.error(error, "error while closing the mysql connection pool")
    if @cacheStrategy?
      @cacheStrategy.quit()


  _getMysqlConnectionPool: ->
    # parse yaml config file
    config = yaml.safeLoad(fs.readFileSync("./config/database.yml", "utf8"))
    poolCluster = mysql.createPoolCluster()
    for host in config.pool
      host.database = config.database
      poolCluster.add(host)
    poolCluster


  getErrorHandler: (error) ->
    # TODO: implement proper error handling
    { reinit: false, reinitOptions: null }


module.exports =
  Application: Application
