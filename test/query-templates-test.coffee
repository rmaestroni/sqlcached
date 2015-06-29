assert = require("assert")
expect = require("expect.js")

queryTemplates = require("../build/query-templates.js")

describe "QueryTemplates", ->

  describe "add", ->
    it "should return an object with properties id and template", ->
      templates = queryTemplates.getSet()
      obj = templates.add("foo", "bar")
      expect(obj.id).to.eql("foo")
      expect(obj.template).to.eql("bar")

  describe "get", ->
    describe "if key is present", ->
      it "should return the specified key", ->
        templates = queryTemplates.getSet()
        templates.add("foo", "bar")
        expect(templates.get("foo").id).to.eql("foo")

    describe "if key is not present", ->
      it "should be undefined", ->
        templates = queryTemplates.getSet()
        expect(templates.get("foo")).to.be(undefined)

  describe "has", ->
    describe "if the key is present", ->
      it "should be true", ->
        templates = queryTemplates.getSet()
        templates.add("foo", "bar")
        expect(templates.has("foo")).to.be(true)

    describe "if the key is not present", ->
      it "should be false", ->
        templates = queryTemplates.getSet()
        expect(templates.has("foo")).to.be(false)

  describe "delete", ->
    it "should remove the specified key", ->
      templates = queryTemplates.getSet()
      templates.add("foo", "bar")
      expect(templates.delete("foo")).to.be(true)
      expect(templates.has("foo")).to.be(false)
