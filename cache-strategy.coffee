fs = require("fs")
yaml = require("js-yaml")
redisLib = require("redis")
redisStrategy = require("./redis-strategy")
memoryStrategy = require("./memory-strategy")

class StrategyBuilder

  constructor: (config) ->
    @concreteStrategy =
      switch config.strategy
        when "redis" then @buildRedisStrategy(config.redis)
        when "memory" then @buildMemoryStrategy()
        else
          throw new Error("Unknown cache strategy")


  buildRedisStrategy: (redisConfig) ->
    @redisClient = redisLib.createClient(redisConfig.port, redisConfig.host)
    redisStrategy.buildStrategy(@redisClient)


  buildMemoryStrategy: ->
    memoryStrategy.buildStrategy()


  getConcreteStrategy: ->
    @concreteStrategy


module.exports =
  build: ->
    new StrategyBuilder(yaml.safeLoad(
      fs.readFileSync("./config/cache.yml", "utf8"))).getConcreteStrategy()
