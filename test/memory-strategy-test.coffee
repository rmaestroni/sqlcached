assert = require("assert")
expect = require("expect.js")
sinon = require("sinon")

memory = require("../build/memory-strategy")

describe "MemoryStrategy", ->

  describe "get", ->
    it "calls 'get' on the dataStore", ->
      store = memory.buildStrategy()
      store.dataStore = { get: sinon.stub().returns("data") }
      callback = sinon.spy()
      store.get("key", callback)
      expect(callback.calledWith(undefined, "data")).to.be(true)

  describe "store", ->
    describe "with no time to live", ->
      it "adds the data to the dataStore", ->
        store = memory.buildStrategy()
        callback = sinon.spy()
        store.store("data-key", "data", "data-keys-set-name", undefined, callback)
        expect(callback.calledWith(undefined)).to.be(true)
        getCallback = sinon.spy()
        store.get("data-key", getCallback)
        expect(getCallback.calledWith(undefined, "data")).to.be(true)

    describe "with time to live", ->

      before -> @clock = sinon.useFakeTimers()
      after -> @clock.restore()

      it "adds the data and sets a timeout to clear it", ->
        store = memory.buildStrategy()
        callback = sinon.spy()
        store.store("data-key", "data", "data-keys-set-name", 10, callback)
        expect(callback.calledWith(undefined)).to.be(true)
        getCallback = sinon.spy()
        store.get("data-key", getCallback)
        expect(getCallback.calledWith(undefined, "data")).to.be(true)
        # after 10 sec...
        @clock.tick(10*1000)
        getCallback = sinon.spy()
        store.get("data-key", getCallback)
        expect(getCallback.calledWith(undefined, undefined)).to.be(true)

  describe "delete", ->
    describe "if the key is found", ->
      it "deletes from the dataStore and responds with 1", ->
        store = memory.buildStrategy()
        # store 2 entries
        store.store("data-key-1", "data 1", "data-keys-set-name", undefined, ->)
        store.store("data-key-2", "data 2", "data-keys-set-name", undefined, ->)
        getCallback = sinon.spy()
        store.get("data-key-1", getCallback)
        expect(getCallback.calledWith(undefined, "data 1")).to.be(true)
        # remove data
        deleteCallback = sinon.spy()
        store.delete("data-key-1", "data-keys-set-name", deleteCallback)
        expect(deleteCallback.calledWith(undefined, 1)).to.be(true)
        # the other one remained there
        store.get("data-key-2", getCallback)
        expect(getCallback.calledWith(undefined, "data 2")).to.be(true)

    describe "if the key is not found", ->
      it "deletes from the dataStore and responds with 1", ->
        store = memory.buildStrategy()
        deleteCallback = sinon.spy()
        store.delete("not-existing-key", "data-keys-set-name", deleteCallback)
        expect(deleteCallback.calledWith(undefined, 0)).to.be(true)

  describe "deleteAll", ->
    describe "if the dataKeys set name exists", ->
      it "deletes all the entries contained in the dataKeysSet", ->
        store = memory.buildStrategy()
        store.store("data-key-1", "data 1", "data-keys-set-name", undefined, ->)
        store.store("data-key-2", "data 2", "data-keys-set-name", undefined, ->)
        store.store("data-key-3", "data 3", "data-keys-set-name", undefined, ->)
        deleteCallback = sinon.spy()
        store.deleteAll("data-keys-set-name", deleteCallback)
        expect(deleteCallback.calledWith(undefined, 3)).to.be(true)

    describe "if the dataKeys set name does not exist", ->
      it "returns { 0 }", ->
        store = memory.buildStrategy()
        deleteCallback = sinon.spy()
        store.deleteAll("data-keys-set-name", deleteCallback)
        expect(deleteCallback.calledWith(undefined, 0)).to.be(true)

  describe "quit", ->
    it "does nothing", ->
      store = memory.buildStrategy()
      expect(store.quit()).to.be.ok()


describe "CacheItem", ->

  describe "constructor", ->
    it "sets a timeout in @timeout if a timeToLive is provided", ->
      callback = sinon.spy()
      item = new memory.CacheItem("key", 10, callback)
      expect(item.timeout).to.be.ok()
      clearTimeout(item.timeout)

  describe "destroy", ->
    it "clears the timeout if present", ->
      callback = sinon.spy()
      item = new memory.CacheItem("key", 10000, callback)
      item.destroy()
      expect(item.timeout.ontimeout).to.not.be.ok()

  describe "equals", ->
    it "is true if object.dataKey match", ->
      obj1 = new memory.CacheItem("foo")
      obj2 = new memory.CacheItem("foo")
      expect(obj1.equals(obj2)).to.be(true)
      expect(obj2.equals(obj1)).to.be(true)

    it "is false if object.dataKey don't match", ->
      obj1 = new memory.CacheItem("foo")
      obj2 = new memory.CacheItem("bar")
      expect(obj1.equals(obj2)).to.be(false)
      expect(obj2.equals(obj1)).to.be(false)
