Client = require './client'
wolfram = require('wolfram').createClient('LQUR86-WLTWTVP9AV')

wolfram_client = new Client
    name: 'Wolfram Alpha client'
    commands:
        wolfram: (msg, cb) ->
            wolfram.query msg.args.join(' '), cb

