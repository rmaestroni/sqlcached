# Module dependencies
express = require("express")
bodyParser = require("body-parser")
mysql = require("mysql")
yaml = require("js-yaml")
fs = require("fs")
redis = require("redis")
u = require("underscore")

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


app.get "/queries", (request, response) ->
  response.writeHead(200, "Content-Type": "application/json")
  response.write(JSON.stringify(queryTemplates.toArray()))
  response.end()

app.post "/queries", (request, response) ->
  id = request.body["id"]
  query = request.body["query"]
  if queryTemplates.has(id)
    response.writeHead(422, "Content-Type": "application/json")
    response.write(JSON.stringify(error: "id already taken"))
  else
    object = queryTemplates.add(id, query)
    response.writeHead(201, "Content-Type": "application/json")
    response.write(JSON.stringify(object))
  response.end()

app.delete "/queries/:id", (request, response) ->
  id = request.params.id
  if object = queryTemplates.get(id)
    if queryTemplates.delete(id)
      database.clearTemplateCache object, (err, reply) ->
        # ignore err
        response.writeHead(200, "Content-Type": "application/json")
        response.write(JSON.stringify(object))
        response.end()
    else
      response.writeHead(500, "Content-Type": "application/json")
      response.write(JSON.stringify(error: "unable to delete the specified object"))
      response.end()
  else
    response.writeHead(404, "Content-Type": "text/plain")
    response.write("404 Not Found")
    response.end()

app.get "/data/:query_id", (request, response) ->
  queryId = request.params.query_id
  queryParams = request.query.query_params
  if (queryTemplate = queryTemplates.get(queryId))?
    database.getData queryTemplate, queryParams, (err, result) ->
      if err?
        [respCode, respEntity] = [500, JSON.stringify(err)]
      else
        [respCode, respEntity] = [200, result]
      response.writeHead(respCode, "Content-Type": "application/json")
      response.write(respEntity)
      response.end()
  else
    response.writeHead(404, "Content-Type": "text/plain")
    response.write("404 Not Found")
    response.end()

app.delete "/data/:query_id/cache", (request, response) ->
  queryId = request.params.query_id
  queryParams = request.query.query_params
  if (queryTemplate = queryTemplates.get(queryId))?
    if u.isEmpty(queryParams)
      # remove everything for the specified template
      database.clearTemplateCache queryTemplate, (err, reply) ->
        # ignore err
        response.writeHead(200, "Content-Type": "text/plain")
        response.write("Removed #{reply} items from cache")
        response.end()
    else
      database.clearCacheEntry queryTemplate, queryParams, (err, reply) ->
        # ignore err
        response.writeHead(200, "Content-Type": "text/plain")
        response.write("Removed #{reply} items from cache")
        response.end()
  else
    response.writeHead(404, "Content-Type": "text/plain")
    response.write("404 Not Found")
    response.end()


# Get command line options via minimists
argv = require("minimist")(process.argv.slice(2))

# Run http server
server = app.listen argv.port || 8081, ->
  host = server.address().address
  port = server.address().port
  console.log("Server listening at http://%s:%s", host, port)
