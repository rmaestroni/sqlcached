u = require("underscore")

DEFAULT_EXP = 3600

class MemcachedStrategy

  constructor: (@memcached) ->


  get: (dataKey, callback) ->
    @memcached.get dataKey, (err, data) ->
      if err
        callback(err)
      else
        callback(undefined, JSON.parse(data))


  store: (dataKey, dataSet, dataKeysSetName, timeToLive, callback) ->
    _memcached = @memcached
    setCallback = (err) ->
      if err
        callback(err)
      else
        _memcached.add dataKeysSetName, '""', DEFAULT_EXP, (err) ->
          if err
            callback(err)
          else
            _memcached.append dataKeysSetName, ", \"#{JSON.stringify(dataKey)}\"", (err) ->
              if err
                callback(err)
              else
                callback(undefined)
    stringifiedData = JSON.stringify(dataSet)
    if timeToLive?
      _memcached.set(dataKey, stringifiedData, timeToLive, setCallback)
    else
      _memcached.set(dataKey, stringifiedData, DEFAULT_EXP, setCallback)


  delete: (dataKey, dataKeysSetName, callback) ->
    self = @
    _memcached = @memcached
    _memcached.del dataKey, (err) ->
      if err
        callback(err)
      else
        _memcached.get dataKeysSetName, (err, data) ->
          if err
            callback(err)
          else
            dataKeysSet = new DataKeysSet(data)
            dataKeysSet.remove(dataKey)
            _memcached.set dataKeysSetName, dataKeysSet.toString(), DEFAULT_EXP, (err) ->
              callback(err)


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


  storeAttachment: (id, object, callback) ->
    _redis = @redis
    _redis.SADD id, JSON.stringify(object), (err, reply) ->
      if err
        callback(err)
      else
        _redis.EXPIRE id, 1800, (err, reply) ->
          callback(err)


  getAttachment: (id, callback) ->
    @redis.SMEMBERS id, (err, reply) ->
      if err
        callback(err)
      else
        callback(undefined, (JSON.parse(item) for item in (reply || [])))


  quit: ->
    @redis.quit()


  parseDataKeysSet: (string) ->
    set = JSON.parse("[#{string}]")


class DataKeysSet
  constructor: (@string) ->

  getItems: ->
    @items ||= @parse(@string)

  setItems: (object) ->
    @items = object

  remove: (item) ->
    @setItems(@getItems().filter (value) -> value != item)

  parse: (string) ->
    @items = JSON.parse("[#{string}]")
      .filter (item) ->
        u.isString(item) && item.length > 0
      .map (item) ->
        JSON.parse(item)

  toString: ->
    @getItems().map (item) ->
      "\"#{JSON.stringify(item)}\""
    .join(", ")



module.exports =
  buildStrategy: (redisClient) -> new RedisStrategy(redisClient)
