Handler = require './module'
{log} = require './helpers'

l = new Handler
    name: "Log Sender man"
    commands:
        log: (message) ->
            log message.data

