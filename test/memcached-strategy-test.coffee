assert = require("assert")
expect = require("expect.js")
sinon = require("sinon")

memcached = require("../build/memcached-strategy")

describe "MemcachedStrategy", ->

  describe "get", ->
    it "reads the data from memcached", ->
      callback = sinon.spy()
      client = {
        get: (dataKey, callback) ->
          callback(undefined, '{ "foo": "bar" }')
      }
      adapter = memcached.buildStrategy(client)
      adapter.get("key", callback)
      expect(callback.calledWith(undefined, { foo: "bar" })).to.be(true)

  describe "store", ->
    it "calls client.set", ->
      client = {
        set: sinon.stub()
      }
      adapter = memcached.buildStrategy(client)
      adapter.store("key", { foo: "bar" }, "key-set-name", 100, ->)
      expect(client.set.calledWith("key", JSON.stringify({ foo: "bar" }), 100)).to.be(true)

    describe "when no timeToLive is provided", ->
      it "uses the default value for expiration", ->
        client = {
          set: sinon.stub()
        }
        adapter = memcached.buildStrategy(client)
        adapter.store("key", { foo: "bar" }, "key-set-name", undefined, ->)
        expect(client.set.calledWith("key", JSON.stringify({ foo: "bar" }), 3600)).to.be(true)

    describe "after having set the key", ->
      it "adds an empty data key set name", ->
        client = {
          set: (key, value, time, callback) ->
            callback(undefined)
          add: sinon.stub()
        }
        adapter = memcached.buildStrategy(client)
        adapter.store(null, null, "key-set-name", null, ->)
        expect(client.add.calledWith("key-set-name", '""', 3600)).to.be(true)

    describe "after having added the empty data key set", ->
      it "appends the data key set name", ->
        client = {
          set: (key, value, time, callback) ->
            callback(undefined)
          add: (dataKeySetName, string, time, callback) ->
            callback(undefined)
          append: sinon.stub()
        }
        adapter = memcached.buildStrategy(client)
        adapter.store("key", null, "key-set-name", null, ->)
        expect(client.append.calledWith("key-set-name", ", #{JSON.stringify('key')}")).to.be(true)

  describe "delete", ->
    it "deletes the data from memcached", ->
      client = {
        del: sinon.stub()
      }
      adapter = memcached.buildStrategy(client)
      adapter.delete("key", "data-keys-set-name", ->)
      expect(client.del.calledWith("key")).to.be(true)

    describe "after having deleted the data", ->
      it "it updates the data keys set", ->
        client = {
          del: (key, callback) ->
            callback()
          get: (dataKeysSetName, callback) ->
            keys = ["key-1", "key-2", "key-3"]
              .map (string) -> JSON.stringify(string)
              .join(', ')
            callback(undefined, keys)
          set: sinon.stub()
        }
        adapter = memcached.buildStrategy(client)
        callback = sinon.spy()
        adapter.delete("key-2", "keys-set-name", callback)
        keysSet = ["", "key-1", "key-3"]
          .map (string) -> JSON.stringify(string)
          .join(', ')
        expect(client.set.calledWith("keys-set-name", keysSet, 3600)).to.be(true)

  describe "deleteAll", ->
    it "deletes all the data cached for the specified query", ->
      client = {
        get: (dataKeySetName, callback) ->
          keys = ["key-1", "key-2", "key-3"]
            .map (string) -> JSON.stringify(string)
            .join(', ')
          callback(undefined, keys)
        del: sinon.stub().callsArg(1)
      }
      adapter = memcached.buildStrategy(client)
      adapter.deleteAll "data-keys-set-name", ->
        expect(client.del.calledWith("key-1")).to.be(true)
        expect(client.del.calledWith("key-2")).to.be(true)
        expect(client.del.calledWith("key-3")).to.be(true)
        expect(client.del.calledWith("data-keys-set-name")).to.be(true)

  describe "storeAttachment", ->
    it "saves the attachment passed in", ->
      client = {
        add: sinon.stub().callsArg(3)
        append: sinon.stub()
      }
      adapter = memcached.buildStrategy(client)
      adapter.storeAttachment("att-id", { foo: "bar" }, ->)
      expect(client.add.calledWith("att-id", JSON.stringify(""), 3600)).to.be(true)
      expect(client.append.calledWith("att-id",
        ", #{JSON.stringify({ foo: 'bar' })}")).to.be(true)

  describe "getAttachment", ->
    it "retrieves the attachment specified", ->
      serializedAttachment = [{ foo: "bar" }, "obj-2", "obj-3"]
        .map (item) -> JSON.stringify(item)
        .join(', ')
      client = {
        get: sinon.stub().callsArgWith(1, undefined, serializedAttachment)
      }
      callback = sinon.spy()
      adapter = memcached.buildStrategy(client)
      adapter.getAttachment("att-id", callback)
      expect(client.get.calledWith("att-id")).to.be(true)
      expect(callback.calledWith(undefined,
        [{ foo: "bar" }, "obj-2", "obj-3"])).to.be(true)

  describe "quit", ->
    it "quits the memcached connection", ->
      client = {
        end: sinon.spy()
      }
      adapter = memcached.buildStrategy(client)
      adapter.quit()
      expect(client.end.called).to.be(true)
