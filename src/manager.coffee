u = require("underscore")
async = require("async")
objectHash = require("object-hash")

TreeVisitor = require("./tree-visitor").TreeVisitor

class Manager
  constructor: (@logger, @queryTemplates, @database) ->


  indexQueries: (callback) ->
    callback(undefined, @queryTemplates.toArray())


  createQuery: (id, query, cachePolicy, callback) ->
    if @queryTemplates.has(id)
      callback({ status: 422, error: "id already taken" })
    else
      callback(undefined, @queryTemplates.add(id, query, cachePolicy))


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


  createQueryAndGetData: (queryId, query, cachePolicy, queryParams, callback) ->
    retrieveData = (err, queryTemplate) =>
      if err
        callback(err)
      else
        @getData(queryId, queryParams, callback)
    #
    if !@queryTemplates.has(queryId)
      @createQuery(queryId, query, cachePolicy, retrieveData)
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
      else if @_hasProperties(item, ["query_id", "query_template", "query_params"])
        # get db data
        id = item.query_id
        query = item.query_template
        params = item.query_params
        cachePolicy = item.cache # optional - could be undefined
        @createQueryAndGetData id, query, cachePolicy, params, (err, data) ->
          currentItem = u.clone(item)
          if err
            itCallback({ error: err, item: currentItem })
          else
            currentItem["resultset"] = data
            itCallback(undefined, currentItem)
      else
        itCallback({ error: "unable to handle #{item}" })
    async.map(request, iterator, done)


  getDataTree: (queryTree, rootParams, attachmentsReq, callback) ->
    self = @

    visit = (tree, parent, transformedP, subtreeIndex, visitCallback) ->
      # transformedP = [ [A11, ..., A1k], [B11, ..., B1j], [C11, ..., C1m], ...]
      #   where each A, B, C, ... is an object
      node = tree["root"]

      buildQueryParams = (queryParamsTemplate, parentObject, errCallback) ->
        queryParams = {}
        for own key, obj of queryParamsTemplate
          switch obj["type"]
            when "constant"
              queryParams[key] = obj.value
            when "parent_attribute"
              queryParams[key] = parentObject[obj.value]
            else
              errCallback("unknown template key type")
        queryParams

      buildRequest = (parentItem) ->
        u.map parentItem, (item, index) ->
          if u.isArray(item)
            buildRequest(item)
          else
            {
              query_id: node["query_id"]
              query_template: node["query_template"]
              query_params: buildQueryParams(node["query_params"], item, visitCallback)
              cache: node["cache"]
            }

      self.getDataBatch(buildRequest(transformedP), (err, batchReply) ->
        if err
          visitCallback(err)
        else
          transformBatchReply = (data) ->
            u.map data, (item, index) ->
              if u.isArray(item)
                transformBatchReply(item)
              else
                item["resultset"]

          visitCallback(undefined, transformBatchReply(batchReply))
      )
      # EOF visit

    visitor = new TreeVisitor(
      (tree) ->
        tree["subtrees"]
      ,
      visit
      ,
      (transfRoot, transfSubtrees, originalRoot, index) ->
        # root: transfRoot
        # subtrees: transfSubtrees
        # index: index
        recurse = (object1, label, object2, path...) ->
          u.map object1, (item, index) ->
            if u.isArray(item)
              recurse(item, label, object2, path..., index)
            else
              associationData = object2
              for i in path
                associationData = associationData[i]
              item[label] = associationData
              item

        u.each originalRoot["root"]["associations"], (associationName, index) ->
          recurse(transfRoot, associationName, transfSubtrees[index])
        transfRoot[0]
    )

    multiRootsTree = rootParams.map (param) ->
      queryTreeClone = u.clone(queryTree)
      queryTreeClone["root"] = u.clone(queryTreeClone["root"])
      queryTreeClone["root"]["query_params"] = u.mapObject param, (value, key) ->
        { value: value, type: "constant" }
      queryTreeClone

    # attachments lookup as the last step
    doneCallback = (resultset) ->
      if attachmentsReq
        self.getAttachments resultset, attachmentsReq, (err, attachments) ->
          if err
            callback(err)
          else
            callback(undefined, {
              resultset: resultset
              attachments: attachments
            })
      else
        callback(undefined, resultset: resultset)

    async.map(
      multiRootsTree,
      (tree, treeCallback) ->
        visitor.visitInPreorder(tree, undefined, [{}], 0, treeCallback)
      (err, results) ->
        if err
          callback(err)
        else
          doneCallback(u.flatten(results, true))
    )


  storeAttachments: (resultset, attachments, callback) ->
    self = @
    async.forEachOf attachments, (attachmentItem, index, itCallback) ->
      if data = resultset[index]
        attachmentId = self._getAttachmentId(attachmentItem["name"], data)
        self.database.storeAttachment(attachmentId, attachmentItem["conditions"],
          attachmentItem["attachment"], itCallback)
      else
        itCallback("No data at position #{index}")
    , (err) ->
      callback(err)


  getAttachments: (resultset, parameters, callback) ->
    self = @
    # TODO handle the case when resultset[index] is undefined or null
    attachmentsLookup = u.map parameters, (param, index) ->
      {
        id: self._getAttachmentId(param["name"], resultset[index])
        conditionValues: param["condition_values"]
      }
    async.map(
      attachmentsLookup,
      (attItem, itCallback) ->
        self.database.getAttachment(attItem.id, attItem.conditionValues, itCallback)
      , callback)


  _getAttachmentId: (attachmentName, data) ->
    data = JSON.stringify(data) if !u.isString(data)
    "att:#{attachmentName}:#{objectHash(data)}"

  # utility function
  _hasProperties: (object, properties) ->
    for property in properties
      return false if !object[property]?
    true


module.exports =
  getApplicationManager: (logger, queryTemplates, database) ->
    new Manager(logger, queryTemplates, database)
