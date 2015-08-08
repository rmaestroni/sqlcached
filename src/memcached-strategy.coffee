u = require("underscore")
us = require("underscore.string")
async = require("async")

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
        _memcached.add dataKeysSetName, new SerializedSet().toString(), DEFAULT_EXP, (err) ->
          if err
            callback(err)
          else
            _memcached.append dataKeysSetName, new SerializedSetPart(dataKey).toString(), (err) ->
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
            dataKeysSet = new SerializedSet(data).parse()
            dataKeysSet.remove(dataKey)
            _memcached.set dataKeysSetName, dataKeysSet.serialize().toString(), DEFAULT_EXP, (err) ->
              callback(err)


  deleteAll: (dataKeysSetName, callback) ->
    _memcached = @memcached
    _memcached.get dataKeysSetName, (err, data) ->
      if err
        callback(err)
      else
        dataKeys = new SerializedSet(data).parse()
        async.each(
          dataKeys.getItems(),
          (dataKey, itCallback) ->
            _memcached.del dataKey, (err) ->
              itCallback(err)
          (err) ->
            if err
              callback(err)
            else
              _memcached.del dataKeysSetName, (err) ->
                callback(err)
        )


  storeAttachment: (id, object, callback) ->
    _memcached = @memcached
    _memcached.add id, new SerializedSet().toString(), DEFAULT_EXP, (err) ->
      if err
        callback(err)
      else
        _memcached.append id, new SerializedSetPart(object).toString(), (err) ->
          callback(err)


  getAttachment: (id, callback) ->
    @memcached.get id, (err, data) ->
      if err
        callback(err)
      else
        callback(undefined, new SerializedSet(data).parse().getItems())


  quit: ->
    # TODO


class SerializedSet

  constructor: (@representation = '""') ->

  toString: ->
    @representation

  parse: ->
    new Set(
      JSON.parse("[#{@representation}]")
        .filter (item) ->
          if u.isString(item)
            !us.isBlank(item)
          else
            true
    )

  add: (serializedPart) ->
    @representation += serializedPart


class SerializedSetPart

  constructor: (@item) ->

  toString: ->
    ", #{JSON.stringify(@item)}"

class Set

  constructor: (@items = []) ->

  remove: (item) ->
    @items = @items.filter (member) ->
      !u.isEqual(member, item)

  serialize: ->
    @items.reduce(
      (serializedSet, item) ->
        serializedSet.add(new SerializedSetPart(item).toString())
        serializedSet
      , new SerializedSet()
    )

  getItems: ->
    @items


module.exports =
  buildStrategy: (client) -> new MemcachedStrategy(client)
