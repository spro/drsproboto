zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'
config = require './config'
_ = require 'underscore'

class Handler

class Client extends EventEmitter

    id: randomString 32
    name: 'Generic Client'
    callosum_address: config.callosum.address
    commands: []

    constructor: (options) ->
        _.extend @, options
        @socket = zmq.socket 'dealer'
        @socket.identity = @id
        @socket.connect @callosum_address
        log "Client connected to " + @callosum_address

        @socket.on 'message', (message_json) =>
            @handleMessage JSON.parse message_json

        @sendRegister()
        @startHeartbeats()

    send: (message) ->
        message.id = randomString 16
        @socket.send JSON.stringify message

    sendRegister: ->
        @send
            command: 'register'
            args:
                id: @id
                name: @name
                handlers: @commands

    sendHeartbeat: ->
        @send
            command: 'heartbeat'
            args:
                id: @id
                name: @name

    startHeartbeats: ->
        setInterval (=> @sendHeartbeat.call(@)), 1000

    handleMessage: (message) ->
        switch message.command
            
            when 'register?'
                log "Callosum downtime, re-registering..."
                @sendRegister()

            else
                if @[message.command]?
                    @[message.command](message)

        @emit 'message', message

if require.main == module
    new Client

else
    module.exports = Client

