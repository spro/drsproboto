Client = require './client'
request = require 'request'
util = require 'util'

http_client = new Client
    name: 'HTTP Client'
    commands:
        get: (message, cb) ->
            console.log "Fetching #{ message.args[0] }"
            request.get {url: message.args[0], json: true}, (err, res, data) ->
                cb null, data

