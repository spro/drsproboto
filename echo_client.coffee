Client = require './client'

echoecho_client = new Client
    name: 'Echo Echo Client'
    commands:
        echo2: (message, cb) ->
            cb null, message.args.concat(message.args).join ' '

