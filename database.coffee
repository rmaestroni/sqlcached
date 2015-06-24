class Database

  constructor: (@dbConnectionPool, @cache) ->

  # Calls the callback specified with the data set related to the query template
  # and the actual parameters passed.
  # The reply is in the form { data: <dataSet>, source: "cache"|"db" }, the
  # dataSet is a js object.
  getData: (queryTemplate, queryParams, callback) ->
    @cache.get queryTemplate.getCachedDataUid(queryParams), (err, reply) =>
      if err
        callback(err)
      else
        if reply
          callback(undefined, { data: reply, source: "cache" })
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

  # Deletes all the cached data for the given query template.
  clearTemplateCache: (queryTemplate, callback) ->
    @cache.deleteAll(queryTemplate.getCachedKeysSetName(), callback)

  # Deletes the cached data related to the <queryTemplate, queryParams> passed.
  clearCacheEntry: (queryTemplate, queryParams, callback) ->
    dataKey = queryTemplate.getCachedDataUid(queryParams)
    dataKeysSetName = queryTemplate.getCachedKeysSetName()
    @cache.delete(dataKey, dataKeysSetName, callback)

  # Stores the specified data into the cache.
  cacheData: (queryTemplate, queryParams, data, callback) ->
    dataKey = queryTemplate.getCachedDataUid(queryParams)
    dataKeysSetName = queryTemplate.getCachedKeysSetName()
    if queryTemplate.hasExpiration()
      @cache.store(dataKey, data, dataKeysSetName,
        queryTemplate.getExpiration(), callback)
    else
      @cache.store(dataKey, data, dataKeysSetName, undefined, callback)


module.exports =
  getDatabase: (connectionPool, concreteCacheStrategy) ->
    new Database(connectionPool, concreteCacheStrategy)
