assert = require("assert")
expect = require("expect.js")
sinon = require("sinon")

redis = require("../redis-strategy")

describe "RedisStrategy", ->

  describe "get", ->
    it "executes GET on Redis"

  describe "store", ->
    it "executes SET on Redis"

  describe "delete", ->
    it "executes DEL on Redis"

  describe "deleteAll", ->
    it "executes DEL on Redis"

  describe "quit", ->
    it "calls quit on the redis client", ->
      fakeClient = quit: -> "foo"
      strategy = redis.buildStrategy(fakeClient)
      expect(strategy.quit()).to.be("foo")
