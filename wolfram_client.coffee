Client = require './client'
config = require './config'
wolfram = require('wolfram').createClient(config.wolfram.app_key)

wolfram_client = new Client
    name: 'Wolfram Alpha client'
    commands:
        wolfram: (msg, cb) ->
            wolfram.query msg.args.join(' '), cb

