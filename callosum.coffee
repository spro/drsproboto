zmq = require 'zmq'
{EventEmitter} = require 'events'
{log} = require './helpers'
_ = require 'underscore'

HEARTBEAT_TIMEOUT = 1000 * 5
REGISTRATION_TIMEOUT = 1000 * 5

class Callosum extends EventEmitter

    pendingRegistrations: {}
    registeredModules: {}
    registeredHandlers: {}

    constructor: ->
        @socket = zmq.socket 'router'
        @socket.on 'message', (module_id, message_json) =>
            @handleMessage module_id, JSON.parse message_json
        @address = 'tcp://0.0.0.0:5003'
        @socket.bindSync @address

        @startCheckups()
        log "Calossum listening at " + @address

    send: (module_id, message) ->
        @socket.send [ module_id, JSON.stringify message ]

    registerModule: (module) ->
        if !@registeredModules[module.id]?
            log "New module registered: #{ module.name } (#{ module.id })"
        else
            log "Re-registering module: #{ module.name } (#{ module.id })"
        @registeredModules[module.id] = module
        @registeredModules[module.id].last_seen = new Date().getTime()
        # TODO: Subscribe them to a message type
        if module.handlers?
            for handler in module.handlers
                @registerHandler handler, module.id

    registerHandler: (handler, module_id) ->
        if !@registeredHandlers[handler]?
            @registeredHandlers[handler] = []
        @registeredHandlers[handler].push module_id
        log "Registered handler: #{ handler }"

    handleHeartbeat: (module) ->
        now = new Date().getTime()

        # Requests re-registration if we haven't seen this client
        if !@registeredModules[module.id]?

            # Set a pending registration time out (so that buffered
            # heartbeats don't create a flood of registration requests)
            if !@pendingRegistrations[module.id]? or
                (now - @pendingRegistrations[module.id]) > REGISTRATION_TIMEOUT
                    @send module.id, command: 'register?'
                    @pendingRegistrations[module.id] = now

        # Module is already known, update its last heartbaet
        else
            @registeredModules[module.id].last_seen = now

    handleMessage: (module_id, message) ->
        switch message.command

            when 'register'
                @registerModule message.args

            when 'heartbeat'
                @handleHeartbeat message.args

            else
                # TODO: Look up handler
                if module_ids = @registeredHandlers[message.command]
                    # Cycle them
                    module_id = module_ids.shift()
                    module_ids.push module_id
                    @send module_id, message

    # See if there are any dead modules by comparing their last heartbeat times
    # to the timeout interval. 
    checkup: ->
        now = new Date().getTime()
        for module_id, module of @registeredModules

            # Check if it should be considered dead
            if (now - module.last_seen) > HEARTBEAT_TIMEOUT

                # Unregister handlers
                for handler in @registeredModules[module_id].handlers
                    handlers = @registeredHandlers[handler]
                    handlers = _.without handlers, module_id
                    @registeredHandlers[handler] = handlers

                # Unregister module
                delete @registeredModules[module_id]
                log "A module has passed: #{ module.name } (#{ module.id })"

    startCheckups: ->
        setInterval (=> @checkup()), 500

callosum = new Callosum()
