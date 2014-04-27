Client = require './client'
config = require './config'
util = require 'util'

echo_client = new Client
    name: 'Echo'
    commands: ['echo']

    echo: (message) ->
        console.log "Echoing #{ util.inspect message }"
        echoed_message =
            response: message.id
            data: message.data
        @send echoed_message

