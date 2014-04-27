Client = require './client'
{log} = require './helpers'

l = new Client
    name: "Log Sender man"
    commands:
        log: (message) ->
            log message.data

