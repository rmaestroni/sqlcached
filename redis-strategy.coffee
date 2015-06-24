class RedisStrategy

  constructor: (@redis) ->


  get: (dataKey, callback) ->
    @redis.GET dataKey, (err, reply) ->
      if err
        callback(err)
      else
        callback(undefined, JSON.parse(reply))


  store: (dataKey, dataSet, dataKeysSetName, timeToLive, callback) ->
    _redis = @redis
    redisSetCallback = (err) ->
      if err
        callback(err)
      else
        _redis.SADD dataKeysSetName, dataKey, (err) ->
          if err
            callback(err)
          else
            callback(undefined)
    stringifiedData = JSON.stringify(dataSet)
    if timeToLive?
      _redis.SET(dataKey, stringifiedData, "EX", timeToLive, redisSetCallback)
    else
      _redis.SET(dataKey, stringifiedData, redisSetCallback)


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


module.exports =
  buildStrategy: (redisClient) -> new RedisStrategy(redisClient)
