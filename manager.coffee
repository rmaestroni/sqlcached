u = require("underscore")._
async = require("async")

class Manager
  constructor: (@logger, @queryTemplates, @database) ->


  indexQueries: (callback) ->
    callback(undefined, @queryTemplates.toArray())


  createQuery: (id, query, callback) ->
    if @queryTemplates.has(id)
      callback({ status: 422, error: "id already taken" })
    else
      callback(undefined, @queryTemplates.add(id, query))


  deleteQuery: (id, callback) ->
    if object = @queryTemplates.get(id)
      if @queryTemplates.delete(id)
        @database.clearTemplateCache object, (err, reply) ->
          # ignore err
          callback(undefined, object)
      else
        callback({ status: 500, error: "unable to delete the specified object" })
    else
      callback({ status: 404, error: "not found" })


  getData: (queryId, queryParams, callback) ->
    if (queryTemplate = @queryTemplates.get(queryId))?
      @database.getData queryTemplate, queryParams, (err, result) =>
        if err
          callback({ status: 500, error: err })
        else
          if result.source is "db"
            # store data in cache
            @database.cacheData queryTemplate, queryParams, result.data, (err) =>
              if err
                callback({ status: 500, error: err })
              else
                callback(undefined, result.data)
          else
            # source is 'cache'
            callback(undefined, result.data)
    else
      callback({ status: 404, error: "not found" })


  deleteDataCache: (queryId, queryParams, callback) ->
    if (queryTemplate = @queryTemplates.get(queryId))?
      if u.isEmpty(queryParams)
        # remove everything for the specified template
        @database.clearTemplateCache queryTemplate, (err, reply) ->
          # ignore err
          callback(undefined, { items: reply })
      else
        @database.clearCacheEntry queryTemplate, queryParams, (err, reply) ->
          # ignore err
          callback(undefined, { items: reply })
    else
      callback({ status: 404, error: "not found" })


  createQueryAndGetData: (queryId, query, queryParams, callback) ->
    retrieveData = (err, queryTemplate) =>
      if err
        callback(err)
      else
        @getData(queryId, queryParams, callback)
    #
    if !@queryTemplates.has(queryId)
      @createQuery(queryId, query, retrieveData)
    else
      retrieveData(undefined, @queryTemplates.get(queryId))


  getDataBatch: (request, callback) ->
    # callback on map completed
    done = (err, mappedAry) =>
      err = { status: 500, error: err } if err # add the http status to err
      callback(err, mappedAry)
    # mapping function
    iterator = (item, itCallback) =>
      # itCallback(err, transformedItem)
      if u.isArray(item)
        # map recursively
        async.map(item, iterator, itCallback)
      else if @_hasProperties(item, ["queryId", "queryTemplate", "queryParams"])
        # get db data
        id = item.queryId
        query = item.queryTemplate
        params = item.queryParams
        @createQueryAndGetData id, query, params, (err, data) ->
          currentItem = u.clone(item)
          if err
            itCallback({ error: err, item: currentItem })
          else
            currentItem["resultset"] = data
            itCallback(undefined, currentItem)
      else
        itCallback({ error: "unable to handle #{item}" })
    async.map(request, iterator, done)


  # utility function
  _hasProperties: (object, properties) ->
    for property in properties
      return false if !object[property]?
    true


module.exports =
  getApplicationManager: (logger, queryTemplates, database) ->
    new Manager(logger, queryTemplates, database)
