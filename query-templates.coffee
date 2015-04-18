Set = require("collections/set")
swig = require("swig")

class QueryTemplate

  constructor: (@id, @template) ->
    @renderer = swig.compile(@template)

  render: (values) ->
    @renderer(values)


class QueryTemplates

  constructor: ->
    equals = (a, b) -> a.id == b.id
    hash = (object) -> object.id
    @queries = new Set(null, equals, hash)

  add: (id, query) ->
    object = new QueryTemplate(id, query)
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
