assert = require("assert")
expect = require("expect.js")
sinon = require("sinon")

database = require("../build/database")

describe "Database", ->

  describe "getData", ->
    it "calls cache.get"

  describe "clearTemplateCache", ->
    it "calls deleteAll on the cache with the cached keys set name", ->
      queryTemplate = { getCachedKeysSetName: sinon.stub().returns("foo") }
      cache = { deleteAll: sinon.spy() }
      database.getDatabase(undefined, cache).clearTemplateCache(queryTemplate,
        "callback")
      expect(queryTemplate.getCachedKeysSetName.calledOnce).to.be(true)
      expect(cache.deleteAll.calledWith("foo", "callback")).to.be(true)

  describe "clearCacheEntry", ->
    it "calls delete on the cache", ->
      queryTemplate = {
        getCachedDataUid: sinon.stub().returns("data uid")
        getCachedKeysSetName: sinon.stub().returns("set name")
      }
      cache = { delete: sinon.spy() }
      database.getDatabase(undefined, cache).clearCacheEntry(queryTemplate,
        "query params", "callback")
      expect(queryTemplate.getCachedDataUid.calledOnce).to.be(true)
      expect(queryTemplate.getCachedKeysSetName.calledOnce).to.be(true)
      expect(cache.delete.calledWith("data uid", "set name", "callback")).to.be(true)

  describe "cacheData", ->
    describe "when the query template has an expiration", ->
      it "calls cache.store with the expiration argument"

    describe "when the query template has no expiration", ->
      it "calls cache.store"
