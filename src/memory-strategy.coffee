SortedMap = require("collections/sorted-map")
SortedSet = require("collections/sorted-set")

class MemoryStrategy

  constructor: ->
    @dataStore = new SortedMap()
    @cachedKeys = new SortedMap()
    @cachedKeys.getDefault = (id) ->
      keysStore = new SortedSet()
      @set(id, keysStore)
      keysStore


  get: (dataKey, callback) ->
    callback(undefined, @dataStore.get(dataKey))


  store: (dataKey, dataSet, dataKeysSetName, timeToLive, callback) ->
    @dataStore.set(dataKey, dataSet)
    if timeToLive?
      expCallback = =>
        @delete(dataKey, dataKeysSetName, ->)
      cacheItem = new CacheItem(dataKey, timeToLive, expCallback)
    else
      cacheItem = new CacheItem(dataKey)
    @storeCacheItem(dataKeysSetName, cacheItem)
    callback(undefined)


  delete: (dataKey, dataKeysSetName, callback) ->
    deleteCount = @dataStore.delete(dataKey) && 1 || 0
    cacheItem = @getCacheItem(dataKeysSetName, dataKey)
    cacheItem.destroy() if cacheItem?
    @deleteCacheItem(dataKeysSetName, dataKey)
    callback(undefined, deleteCount)


  deleteAll: (dataKeysSetName, callback) ->
    deleteCount = 0
    @forEachCacheItem dataKeysSetName, (cacheItem) =>
      deleteCount++ if @dataStore.delete(cacheItem.dataKey)
      cacheItem.destroy()
    @deleteAllCacheItems(dataKeysSetName)
    callback(undefined, deleteCount)


  quit: -> true # no-op


  storeCacheItem: (dataKeysSetName, cacheItem) ->
    @cachedKeys.get(dataKeysSetName).push(cacheItem)


  getCacheItem: (dataKeysSetName, dataKey) ->
    @cachedKeys.get(dataKeysSetName).get(dataKey: dataKey)


  deleteCacheItem: (dataKeysSetName, dataKey) ->
    @cachedKeys.get(dataKeysSetName).delete(dataKey: dataKey)


  forEachCacheItem: (dataKeysSetName, callback) ->
    @cachedKeys.get(dataKeysSetName).forEach(callback)


  deleteAllCacheItems: (dataKeysSetName) ->
    @cachedKeys.get(dataKeysSetName).clear()


# Instances of this class wrap a data key and a timer, to remove the data from
# the cache when the timeout expires.
#
class CacheItem

  # @param dataKey [String] the unique key for the cached data
  # @param timeToLive [Integer] is expressed in seconds
  # @param expCallback [Function] the function to call when the timeout expires
  constructor: (dataKey, timeToLive, expCallback) ->
    @dataKey = dataKey
    @timeout = setTimeout(expCallback, 1000 * timeToLive) if timeToLive?

  destroy: ->
    clearTimeout(@timeout) if @timeout?

  equals: (other) ->
    @dataKey == other.dataKey

  compare: (other) ->
    if @dataKey < other.dataKey
      -Infinity
    else
      Infinity


module.exports =
  buildStrategy: -> new MemoryStrategy()
  CacheItem: CacheItem
