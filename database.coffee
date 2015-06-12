class Database

  constructor: (@dbConnectionPool, @redis) ->

  getData: (queryTemplate, queryParams, callback) ->
    @redis.GET queryTemplate.getCachedDataUid(queryParams), (err, reply) =>
      if err
        callback(err)
      else
        if reply
          callback(undefined, { data: JSON.parse(reply), source: "cache" })
        else
          @dbConnectionPool.getConnection (err, connection) ->
            if err
              callback(err)
            else
              sql = queryTemplate.render(queryParams)
              connection.query sql, (err, rows, fields) ->
                connection.release()
                if err
                  callback(err)
                else
                  callback(undefined, { data: rows, source: "db" })


  clearTemplateCache: (queryTemplate, callback) ->
    _redis = @redis
    cachedKeysSetName = queryTemplate.getCachedKeysSetName()
    iterator = (cursor) ->
      _redis.SSCAN cachedKeysSetName, cursor, (err, reply) ->
        # reply[0] is the next cursor, reply[1] is an array of keys
        if err
          callback(err)
        else
          _redis.DEL reply[1], (err) ->
            if err
              callback(err)
            else
              if reply[0] is "0" # stop iteration
                # remove the set of the cached keys
                _redis.DEL cachedKeysSetName, (err) ->
                  if err
                    callback(err)
                  else
                    callback(undefined)
              else
                iterator(reply[0])
    iterator("0")


  clearCacheEntry: (queryTemplate, queryParams, callback) ->
    cachedDataUid = queryTemplate.getCachedDataUid(queryParams)
    @redis.DEL cachedDataUid, (err, reply) =>
      if err
        callback(err)
      else
        @redis.SREM queryTemplate.getCachedKeysSetName(), cachedDataUid, (err) ->
          if err
            callback(err)
          else
            callback(undefined, reply)


  cacheData: (queryTemplate, queryParams, data, callback) ->
    _redis = @redis
    queryUid = queryTemplate.getCachedDataUid(queryParams) # unique cache key for the data
    redisSetCallback = (err) ->
      if err
        callback(err)
      else
        _redis.SADD queryTemplate.getCachedKeysSetName(), queryUid, (err) ->
          if err
            callback(err)
          else
            callback(undefined)
    stringifiedData = JSON.stringify(data)
    if queryTemplate.hasExpiration()
      _redis.SET(queryUid, stringifiedData, "EX",
        queryTemplate.getExpiration(), redisSetCallback)
    else
      _redis.SET(queryUid, stringifiedData, redisSetCallback)


module.exports =
  getDatabase: (connectionPool, redisClient) ->
    new Database(connectionPool, redisClient)
