# Module dependencies
express = require("express")
bodyParser = require("body-parser")
mysql = require("mysql")
yaml = require("js-yaml")
fs = require("fs")
redis = require("redis")
u = require("underscore")._

getMysqlConnectionPool = ->
  # parse yaml config file
  config = yaml.safeLoad(fs.readFileSync("./config/database.yml", "utf8"))
  poolCluster = mysql.createPoolCluster()
  for host in config.pool
    host.database = config.database
    poolCluster.add(host)
  poolCluster

mysqlConnectionPool = getMysqlConnectionPool()
redisClient = redis.createClient()

process.on "SIGINT", ->
  console.log "> received SIGINT, shutting down..."
  mysqlConnectionPool.end (error) ->
    console.log "error in closing mysql connection pool: #{error}" if error?
  redisClient.quit()
  process.exit()

# Application modules
queryTemplates = require("./query-templates").getSet()
database = require("./database").getDatabase(mysqlConnectionPool, redisClient)
manager = require("./manager").getApplicationManager(queryTemplates, database)

# General error handler
errorHandler = (err, req, res, next) ->
  res.writeHead(500, "Content-Type": "application/json")
  res.write(JSON.stringify( error: err.toString() ))
  res.end()

# Init Express application
app = express()
app.use(bodyParser.urlencoded(extended: false))
app.use(bodyParser.json())
app.use(errorHandler) # must be the last middleware registered

httpCallback = (err, entity, httpResponse, successCode) ->
  if err
    httpResponse.writeHead(err.status, "Content-Type": "application/json")
    if u.isString(err)
      httpResponse.write(err)
    else
      httpResponse.write(JSON.stringify(err))
  else
    httpResponse.writeHead(successCode, "Content-Type": "application/json")
    if u.isString(entity)
      httpResponse.write(entity)
    else
      httpResponse.write(JSON.stringify(entity))
  httpResponse.end()


app.get "/queries", (request, response) ->
  manager.indexQueries (err, value) ->
    httpCallback(err, value, response, 200)


app.post "/queries", (request, response) ->
  id = request.body["id"]
  query = request.body["query"]
  manager.createQuery id, query, (err, value) ->
    httpCallback(err, value, response, 201)


app.delete "/queries/:id", (request, response) ->
  manager.deleteQuery request.params.id, (err, reply) ->
    httpCallback(err, reply, response, 200)


app.get "/data/:query_id", (request, response) ->
  queryId = request.params.query_id
  queryParams = request.query.query_params
  manager.getData queryId, queryParams, (err, reply) ->
    httpCallback(err, reply, response, 200)


app.post "/data-batch", (request, response) ->
  batchData = request.body["batch"]
  manager.getDataBatch batchData, (err, reply) ->
    httpCallback(err, reply, response, 200)


app.delete "/data/:query_id/cache", (request, response) ->
  queryId = request.params.query_id
  queryParams = request.query.query_params
  manager.deleteDataCache queryId, queryParams, (err, reply) ->
    httpCallback(err, reply, response, 200)


# Get command line options via minimists
argv = require("minimist")(process.argv.slice(2))

# Run http server
server = app.listen argv.port || 8081, ->
  host = server.address().address
  port = server.address().port
  console.log("Server listening at http://%s:%s", host, port)
