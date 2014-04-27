zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'
_ = require 'underscore'
config = require './config'

class Handler extends EventEmitter
    
    id: randomString 36
    name: 'Generic Handler'
    callosum_address: config.callosum.address
    commands: {}

    constructor: (options) ->
        _.extend @, options
        @socket = zmq.socket 'dealer'
        @socket.identity = @id
        @socket.on 'message', (message_json) =>
            @handleMessage JSON.parse message_json
        @socket.connect @callosum_address
        log "Handler connected to " + @callosum_address
        @sendRegister()
        @startHeartbeats()

    send: (message) ->
        @socket.send JSON.stringify message

    sendRegister: ->
        @send
            command: 'register'
            args:
                id: @id
                name: @name
                handlers: _.keys @commands

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
                if @commands[message.command]?
                    @commands[message.command](message)
                else
                    log "Got an unknown message: " + util.inspect message

if require.main == module
    new Handler

else
    module.exports = Handler
