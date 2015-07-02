class RedisStrategy

  constructor: (@redis) ->


  get: (dataKey, callback) ->
    @redis.GET dataKey, (err, reply) ->
      if err
        callback(err)
      else
        callback(undefined, JSON.parse(reply))


  store: (dataKey, dataSet, dataKeysSetName, timeToLive, callback) ->
    stringifiedData = JSON.stringify(dataSet)
    multi = @redis.multi()
    if timeToLive?
      multi.SET(dataKey, stringifiedData, "EX", timeToLive)
    else
      multi.SET(dataKey, stringifiedData)
    multi.SADD dataKeysSetName, dataKey, (err) ->
    multi.exec (err, replies) ->
      callback(err)


  delete: (dataKey, dataKeysSetName, callback) ->
    @redis.DEL dataKey, (err, reply) =>
      if err
        callback(err)
      else
        @redis.SREM dataKeysSetName, dataKey, (err) ->
          if err
            callback(err)
          else
            callback(undefined, reply)


  deleteAll: (dataKeysSetName, callback) ->
    _redis = @redis
    iterator = (cursor) ->
      _redis.SSCAN dataKeysSetName, cursor, (err, reply) ->
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
                _redis.DEL dataKeysSetName, (err) ->
                  if err
                    callback(err)
                  else
                    callback(undefined)
              else
                iterator(reply[0])
    iterator("0")


  quit: ->
    @redis.quit()


module.exports =
  buildStrategy: (redisClient) -> new RedisStrategy(redisClient)
