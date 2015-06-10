u = require("underscore")._
async = require("async")

class TreeVisitor

  constructor: (@getSubtrees, @visit, @resultBuilder) ->

  visitInPreorder: (tree, parent, transformedParent, index, callback) ->
    self = @
    self.visit tree, parent, transformedParent, index, (err, result) ->
      if err
        callback(err)
      else
        if u.isEmpty(subtrees = self.getSubtrees(tree))
          callback(undefined, self.resultBuilder(result, []))
        else
          async.map(
            u.map(subtrees, (item, index) -> node: item, index: index )
            ,
            (subtreeWrp, subTreeCallback) ->
              subtree = subtreeWrp.node
              index = subtreeWrp.index
              self.visitInPreorder(subtree, tree, result, index, subTreeCallback)
            ,
            (err, subtreesMapped) ->
              if err
                callback(err)
              else
                callback(undefined, self.resultBuilder(result, subtreesMapped))
          )

module.exports =
  TreeVisitor: TreeVisitor
