fs = require("fs")
yaml = require("js-yaml")
redisLib = require("redis")
Memcached = require("memcached")
spawn = require("child_process").spawn
sleep = require("./sleep").sleep
redisStrategy = require("./redis-strategy")
memcachedStrategy = require("./memcached-strategy")
memoryStrategy = require("./memory-strategy")

# TODO: why @redisClient??
class StrategyBuilder

  constructor: (config) ->
    @concreteStrategy =
      switch config.strategy
        when "redis" then @buildRedisStrategy(config.redis)
        when "memory" then @buildMemoryStrategy()
        when "redis-spawn" then @buildRedisSpawnStrategy()
        when "memcached" then @buildMemcachedStrategy(config.memcached)
        else
          throw new Error("Unknown cache strategy")


  buildRedisStrategy: (redisConfig) ->
    @redisClient = redisLib.createClient(redisConfig.port, redisConfig.host)
    redisStrategy.buildStrategy(@redisClient)


  buildMemcachedStrategy: (memcachedConfig) ->
    host = memcachedConfig.host
    port = memcachedConfig.port
    poolSize = memcachedConfig.pool
    memcachedStrategy.buildStrategy(
      new Memcached("#{host}:#{port}", {
        poolSize: poolSize
        maxKeySize: 1024
        maxValue: 10 * 2**20
        idle: 120000
      })
    )


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
