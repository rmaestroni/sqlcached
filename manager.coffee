u = require("underscore")._
async = require("async")

class Manager
  constructor: (@queryTemplates, @database) ->


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
        @database.clearTemplateCache object, (err, reply) =>
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
          callback(undefined, result)
    else
      callback({ status: 404, error: "not found" })


  deleteDataCache: (queryId, queryParams, callback) ->
    if (queryTemplate = @queryTemplates.get(queryId))?
      if u.isEmpty(queryParams)
        # remove everything for the specified template
        @database.clearTemplateCache queryTemplate, (err, reply) =>
          # ignore err
          callback(undefined, { items: reply })
      else
        @database.clearCacheEntry queryTemplate, queryParams, (err, reply) =>
          # ignore err
          callback(undefined, { items: reply })
    else
      callback({ status: 404, error: "not found" })


  createQueryAndGetData: (queryId, query, queryParams, callback) ->
    retrieveData = (err, queryTemplate) =>
      if err
        callback(err)
      else
        queryParams = [queryParams] if !u.isArray(queryParams)
        iterator = (item, itCallback) =>
          @getData(queryId, item, itCallback)
        done = (err, mappedAry) ->
          callback(err, mappedAry)
        async.map(queryParams, iterator, done)
    #
    if !@queryTemplates.has(queryId)
      @createQuery(queryId, query, retrieveData)
    else
      retrieveData(undefined, @queryTemplates.get(queryId))


module.exports =
  getApplicationManager: (queryTemplates, database) ->
    new Manager(queryTemplates, database)
