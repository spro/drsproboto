somata = require 'somata'
util = require 'util'
DrSprobotoClient = require './client'

so_client = new somata.Client

so_client.on 'nexus:updates', 'update', (err, update) ->

    # Check if this is a message to @drsproboto
    if update.type == 'command' && update.receiver?.match /^dr/

        # Run as a script and return the response
        script = update.body
        dr_client.runScript script, null, (err, response) ->
            response_message =
                type: 'response'
                sender: 'dr'
                data: response
            so_client.remote 'nexus:updates', 'send', response_message, -> # ...

dr_client = new DrSprobotoClient
    name: "Somata <-> Dr Sproboto bridge"
    commands:
        remote: (msg, cb) ->
            so_client.remote msg.args..., cb

so_service = new somata.Service 'drsproboto',
    script: (script, cb) ->
        dr_client.runScript script, null, cb

