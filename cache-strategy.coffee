fs = require("fs")
yaml = require("js-yaml")
redisLib = require("redis")
spawn = require("child_process").spawn
sleep = require("sleep").sleep
redisStrategy = require("./redis-strategy")
memoryStrategy = require("./memory-strategy")

class StrategyBuilder

  constructor: (config) ->
    @concreteStrategy =
      switch config.strategy
        when "redis" then @buildRedisStrategy(config.redis)
        when "memory" then @buildMemoryStrategy()
        when "redis-spawn" then @buildRedisSpawnStrategy()
        else
          throw new Error("Unknown cache strategy")


  buildRedisStrategy: (redisConfig) ->
    @redisClient = redisLib.createClient(redisConfig.port, redisConfig.host)
    redisStrategy.buildStrategy(@redisClient)


  buildMemoryStrategy: ->
    memoryStrategy.buildStrategy()


  buildRedisSpawnStrategy: ->
    spawn("redis-server", ["config/redis.conf"], detached: false)
    sleep(3)
    @redisClient = redisLib.createClient("tmp/redis.sock")
    redisStrategy.buildStrategy(@redisClient)


  getConcreteStrategy: ->
    @concreteStrategy


module.exports =
  build: ->
    new StrategyBuilder(yaml.safeLoad(
      fs.readFileSync("./config/cache.yml", "utf8"))).getConcreteStrategy()
