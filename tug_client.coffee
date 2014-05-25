Client = require './client'
exec = require('child_process').exec

tug_client = new Client
    name: 'tug'
    commands:
        tug: (message, respond) ->
            exec 'tug ' + message.args.join(' '), (err, stdout, stderr) ->
                respond null, stdout

