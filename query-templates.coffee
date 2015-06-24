Set = require("collections/set")
swig = require("swig")
objectHash = require("object-hash")
u = require("underscore")

class QueryTemplate

  constructor: (@id, @template, @cache = true) ->
    @renderer = swig.compile(@template)

  # Fills this query template with the values provided, returns a runnable
  # SQL query.
  render: (values) ->
    @renderer(values)

  # Returns a unique identifier for the pair
  # <this query template; actual parameters>
  getCachedDataUid: (queryParams) ->
    "#{@id}:#{objectHash(queryParams)}"

  # Returns a unique name set label for the collection of the cached keys
  # (see getCachedDataUid), relative to this query template.
  getCachedKeysSetName: ->
    "#{@id}:cached-keys"

  # Returns true if this query template has an expiration timeout for the
  # cached data, false otherwise.
  hasExpiration: ->
    u.isNumber(@cache)

  # Returns the expiration timeout for the cached data of this query template,
  # if any.
  getExpiration: ->
    @cache


# This class implements a set to store all the query templates managed in the
# application.
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
