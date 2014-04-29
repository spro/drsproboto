zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'
config = require './config'
_ = require 'underscore'

HEARTBEAT_INTERVAL = 5000

class Client extends EventEmitter

    id: randomString 8
    name: 'Generic Client'
    callosum_address: config.callosum.address
    commands: []

    constructor: (options) ->
        _.extend @, options
        @socket = zmq.socket 'dealer'
        @socket.identity = @id
        @socket.connect @callosum_address
        log "#{ @name } connected to #{ @callosum_address }"

        @socket.on 'message', (message_json) =>
            @handleMessage JSON.parse message_json

        @sendRegister()
        @startHeartbeats()

        process.on 'SIGINT', =>
            @sendUnregister()
            process.exit()

    send: (message) ->
        message.id = randomString 16
        @socket.send JSON.stringify message
        message

    sendUnregister: ->
        @send
            type: 'unregister'

    sendRegister: ->
        @send
            type: 'register'
            args:
                id: @id
                name: @name
                handlers: _.keys @commands

    sendHeartbeat: ->
        @send
            type: 'heartbeat'
            args:
                id: @id
                name: @name

    startHeartbeats: ->
        setInterval (=> @sendHeartbeat.call(@)), HEARTBEAT_INTERVAL

    handleMessage: (message) ->
        switch message.command
            
            when 'register?'
                log "Callosum downtime, re-registering..."
                @sendRegister()

            else
                if @commands[message.command]?
                    # Command may call back response data or a full response message
                    @commands[message.command] message, (err, data, response) =>
                        if !response?
                            response =
                                data: data
                        response.type = 'response'
                        response.rid = message.id
                        @send response

        @emit 'message', message

if require.main == module
    new Client

else
    module.exports = Client

