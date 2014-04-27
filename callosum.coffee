zmq = require 'zmq'
{EventEmitter} = require 'events'
{log} = require './helpers'
_ = require 'underscore'
util = require 'util'

HEARTBEAT_TIMEOUT = 1000 * 5
REGISTRATION_TIMEOUT = 1000 * 5

class Callosum extends EventEmitter

    pendingRegistrations: {}
    pendingCommands: {}
    registeredClients: {}
    registeredHandlers: {}

    constructor: ->
        @socket = zmq.socket 'router'
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id, JSON.parse message_json
        @address = 'tcp://0.0.0.0:5003'
        @socket.bindSync @address

        @startCheckups()
        log "Calossum listening at " + @address

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    registerClient: (client) ->
        if !@registeredClients[client.id]?
            log "New client registered: #{ client.name } (#{ client.id })"
        else
            log "Re-registering client: #{ client.name } (#{ client.id })"
        @registeredClients[client.id] = client
        @registeredClients[client.id].last_seen = new Date().getTime()
        # TODO: Subscribe them to a message type
        if client.handlers?
            for handler in client.handlers
                @registerHandler handler, client.id

    registerHandler: (handler, client_id) ->
        if !@registeredHandlers[handler]?
            @registeredHandlers[handler] = []
        @registeredHandlers[handler].push client_id
        log "Registered handler: #{ handler }"

    handleHeartbeat: (client) ->
        now = new Date().getTime()

        # Requests re-registration if we haven't seen this client
        if !@registeredClients[client.id]?

            # Set a pending registration time out (so that buffered
            # heartbeats don't create a flood of registration requests)
            if !@pendingRegistrations[client.id]? or
                (now - @pendingRegistrations[client.id]) > REGISTRATION_TIMEOUT
                    @send client.id, command: 'register?'
                    @pendingRegistrations[client.id] = now

        # Client is already known, update its last heartbaet
        else
            @registeredClients[client.id].last_seen = now

    handleMessage: (client_id, message) ->
        if message.command?
            @handleCommand client_id, message

        else if message.response?
            @pendingCommands[message.response](message)

    handleCommand: (client_id, message) ->
        switch message.command

            when 'register'
                @registerClient message.args

            when 'heartbeat'
                @handleHeartbeat message.args

            else
                log "<#{ client_id }>: #{ util.inspect message }"

                @handleClientCommand client_id, message

    handleClientCommand: (from_client_id, command_message) ->
        if to_client_ids = @registeredHandlers[command_message.command]
            # Get an available handler client
            to_client_id = to_client_ids.shift()
            to_client_ids.push to_client_id
            # Set up repsonse callback
            @pendingCommands[command_message.id] = (response_message) =>
                @send from_client_id, response_message
            # Send it off
            @send to_client_id, command_message

    # See if there are any dead clients by comparing their last
    # heartbeat times to the timeout interval. 
    checkup: ->
        now = new Date().getTime()
        for client_id, client of @registeredClients

            # Check if it should be considered dead
            if (now - client.last_seen) > HEARTBEAT_TIMEOUT

                # Unregister handlers
                for handler in @registeredClients[client_id].handlers
                    handlers = @registeredHandlers[handler]
                    handlers = _.without handlers, client_id
                    @registeredHandlers[handler] = handlers

                # Unregister client
                delete @registeredClients[client_id]
                log "A client has passed: #{ client.name } (#{ client.id })"

    startCheckups: ->
        setInterval (=> @checkup()), 500

callosum = new Callosum()

