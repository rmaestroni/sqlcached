Set = require("collections/set")
swig = require("swig")
objectHash = require("object-hash")
u = require("underscore")

class QueryTemplate

  constructor: (@id, @template, @cache = true) ->
    @renderer = swig.compile(@template)

  render: (values) ->
    @renderer(values)

  getCachedDataUid: (queryParams) ->
    "#{@id}:#{objectHash(queryParams)}"

  getCachedKeysSetName: ->
    "#{@id}:cached-keys"

  hasExpiration: ->
    u.isNumber(@cache)

  getExpiration: ->
    @cache


class QueryTemplates

  constructor: ->
    equals = (a, b) -> a.id == b.id
    hash = (object) -> object.id
    @queries = new Set(null, equals, hash)

  add: (id, query, cachePolicy) ->
    object = new QueryTemplate(id, query, cachePolicy)
    @queries.add(object)
    object

  get: (id) ->
    @queries.get(id: id)

  has: (id) ->
    @queries.has(id: id)

  delete: (id) ->
    @queries.delete(id: id)

  toArray: ->
    @queries.toArray()


module.exports =
  getSet: -> new QueryTemplates()
