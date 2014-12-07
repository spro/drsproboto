somata = require 'somata'
util = require 'util'
DrSprobotoClient = require './client'

so_client = new somata.Client

dr_client = new DrSprobotoClient
    name: "Somata <-> Dr Sproboto bridge"
    commands:
        remote: (msg, cb) ->
            so_client.remote msg.args..., cb

so_service = new somata.Service 'drsproboto',
    script: (script, cb) ->

        dr_client.send
            type: 'script'
            script: script

        dr_client.on 'message', (message) ->
            cb null, message

