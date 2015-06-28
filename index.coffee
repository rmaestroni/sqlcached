# Get command line options via minimists
argv = require("minimist")(process.argv.slice(2))
# Create a logger
logger = require("bunyan").createLogger(name: "sqlcached")

# sqlcached main module
Application = require("./application").Application

# Factory method
buildApplication = (argv, logger) ->
  new Application(argv, logger)

app = buildApplication(argv, logger)

# Cleanup on process termination
process.on "SIGINT", ->
  logger.info "> received SIGINT, terminating application..."
  app.term()
  process.exit(0)

# Reinit when an exception bubbles up
process.on "uncaughtException", (err) ->
  errorHandler = app.getErrorHandler(err)
  if errorHandler.reinit
    logger.error(err, "Got uncaught exception, going to reinit the application...")
    app = buildApplication(argv, logger)
    app.init(errorHandler.reinitOptions)
  else
    logger.fatal(err, "Fatal error")
    process.exit(1)

# Run
app.init()
