hash = require("object-hash")

class Database

  constructor: (@dbConnectionPool, @redis) ->

  getData: (queryTemplate, queryParams, callback) ->
    templateId = queryTemplate.id
    paramsId = hash(queryParams)
    @redis.hget templateId, paramsId, (err, reply) =>
      if err
        callback(err)
      else
        if reply
          callback(undefined, reply)
        else
          @dbConnectionPool.getConnection (err, connection) =>
            if err
              callback(err)
            else
              sql = queryTemplate.render(queryParams)
              connection.query sql, (err, rows, fields) =>
                connection.release()
                if err
                  callback(err)
                else
                  rows = JSON.stringify(rows)
                  @redis.hset(templateId, paramsId, rows)
                  callback(undefined, rows)

  clearTemplateCache: (queryTemplate, callback) ->
    templateId = queryTemplate.id
    @redis.del templateId, (err, reply) =>
      if err
        callback(err)
      else
        callback(undefined, reply)

  clearCacheEntry: (queryTemplate, queryParams, callback) ->
    templateId = queryTemplate.id
    paramsId = hash(queryParams)
    @redis.hdel templateId, paramsId, (err, reply) =>
      if err
        callback(err)
      else
        callback(undefined, reply)


module.exports =
  getDatabase: (connectionPool, redisClient) ->
    new Database(connectionPool, redisClient)
