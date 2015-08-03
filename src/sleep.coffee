module.exports =
  sleep: (seconds) ->
    timestamp = new Date().getTime() + (seconds * 1000)
    while new Date().getTime() <= timestamp
      ;
