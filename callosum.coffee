zmq = require 'zmq'
{EventEmitter} = require 'events'
{randomString, log} = require './helpers'
_ = require 'underscore'
pipeline = require '../qnectar/pipeline/pipeline'
util = require 'util'
redis = require('redis').createClient()

VERBOSE = false
HEARTBEAT_INTERVAL = 5000
HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL * 5
REGISTRATION_TIMEOUT = HEARTBEAT_INTERVAL * 5

class Callosum

    pending_registrations: {}
    pending_commands: {}
    registered_clients: {}
    registered_handlers: {}

    constructor: ->
        @socket = zmq.socket 'router'
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json
        @address = 'tcp://0.0.0.0:5003'
        @socket.bindSync @address

        @startCheckups()
        log "Calossum listening at " + @address

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    unregisterClient: (client_id) ->
        # Unregister handlers
        for handler in @registered_clients[client_id].handlers
            handlers = @registered_handlers[handler]
            handlers = _.without handlers, client_id
            @registered_handlers[handler] = handlers

        # Unregister client
        delete @registered_clients[client_id]
        log "Unregistered client: #{ client_id }", color: 'red'

    # Expects a message in the format
    # 
    # ```
    # type: "register"
    # args:
    #     name: "Example Client"
    #     handlers: ["handler1", "handler2"]
    # ```

    registerClient: (client_id, message) ->
        if !@registered_clients[client_id]?
            log "New client registered: #{ message.args.name } (#{ client_id })", color: 'yellow'
        else
            log "Re-registering client: #{ message.args.name } (#{ client_id })", color: 'yellow'

        @registered_clients[client_id] = message.args
        @registered_clients[client_id].last_seen = new Date().getTime()

        # TODO: Subscribe them to a message type
        if message.args.handlers?
            for handler in message.args.handlers
                @registerHandler handler, client_id

    registerHandler: (handler, client_id) ->
        if !@registered_handlers[handler]?
            @registered_handlers[handler] = []
        @registered_handlers[handler].push client_id
        log "Registered handler: #{ handler }", color: 'brightYellow'

    handleHeartbeat: (client_id, message) ->
        now = new Date().getTime()

        # Requests re-registration if we haven't seen this client
        if !@registered_clients[client_id]?

            # Set a pending registration time out (so that buffered
            # heartbeats don't create a flood of registration requests)
            if !@pending_registrations[client_id]? or
                (now - @pending_registrations[client_id]) > REGISTRATION_TIMEOUT
                    @send client_id, command: 'register?'
                    @pending_registrations[client_id] = now

        # Client is already known, update its last heartbaet
        else
            @registered_clients[client_id].last_seen = now

    saveMessage: (message) ->
        save_message = 'mongo insert messages $!'
        pipeline.execPipelines save_message, message, callosum_context, (err, saved_message) => # ...

    handleMessage: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE

        if message.type != 'heartbeat'
            if !message.sender
                message.sender = @registered_clients[client_id]?.name || client_id
            if !message.suppress?
                @saveMessage message

        switch message.type

            when 'register'
                @registerClient client_id, message

            when 'unregister'
                @unregisterClient client_id

            when 'heartbeat'
                @handleHeartbeat client_id, message

            when 'script'
                @handleScript client_id, message

            when 'command'
                @handleCommand client_id, message

            when 'response'
                @handleResponse client_id, message

            else
                log 'Unrecognized message: ' + util.inspect message

    handleScript: (client_id, message) ->
        log "<#{ client_id }> → SCRIPT [#{ message.id }] #{ message.script }", color: 'cyan'
        pipeline.execPipelines message.script, message.data, callosum_context, (err, data) =>
            if err
                log 'ERROR ' + err, color: 'red'
                @send client_id,
                    id: message.id
                    error: err.toString()
            else
                @send client_id,
                    id: message.id
                    data: data

    handleCommand: (client_id, message) ->
        log "<#{ client_id }> → COMMAND [#{ message.id }] #{ message.command }", color: 'blue'
        if handler_client_id = @selectHandler message.command
            # Set up repsonse callback
            if !message.origin?
                message.origin = client_id
            @pending_commands[message.id] =
                message: message
            # Send it off
            @send handler_client_id, message

    handleResponse: (client_id, message) ->
        log "<#{ client_id }> → RESPONSE [#{ message.rid }]", color: 'green'
        pending_command = @pending_commands[message.rid]
        if _.isFunction pending_command
            pending_command null, message.data
        else
            @send pending_command.origin, message
        delete @pending_commands[message.rid]

    selectHandler: (command) ->
        if to_client_ids = @registered_handlers[command]
            # Get an available handler client
            to_client_id = to_client_ids.shift()
            to_client_ids.push to_client_id
            return to_client_id

    # Handling remote commands
    #
    # A Handler is selected from those registered, and a message
    # is sent to that handler with a unique `id` to be saved in
    # `pending_commands`.
    #
    # Commands may occur in one of two ways, each has a key prefix
    # to distinguish it in the `pending_commands` queue:
    #
    # * Sent directly from another client in a `command` message.
    #   Prefix: `client:`
    # * Triggered from within a pipeline execution while 
    #   interpreting a `script` message.
    #   Prefix: `pipeline:`
    #
    # When the command handler has a result, it will check the prefix
    # they will respond with `rid` equal to that `id`.

    handleRemoteCommand: (from_client_id, command_message) ->
        log "#{ from_client_id } -> #{ util.inspect command_message }"

    # See if there are any dead clients by comparing their last
    # heartbeat times to the timeout interval. 
    checkup: ->
        now = new Date().getTime()
        for client_id, client of @registered_clients

            # Check if it should be considered dead
            if (now - client.last_seen) > HEARTBEAT_TIMEOUT

                @unregisterClient client_id

    startCheckups: ->
        setInterval (=> @checkup()), 500

# Extend the qnectar pipeline context to look up functions
# in the set of registered handlers.

class CallosumContext extends pipeline.Context
CallosumContext::lookup = (cmd) ->
    found = super
    if !found?
        if callosum.registered_handlers[cmd]?
            found = (inp, args, ctx, cb) =>
                # Do the thing
                to_client_id = callosum.selectHandler cmd
                command_message =
                    id: randomString 16
                    command: cmd
                    data: inp
                    args: args
                callosum.send to_client_id, command_message
                callosum.pending_commands[command_message.id] = cb
    return found

callosum_context = new CallosumContext()
    .use('html')
    .use(require('../qnectar/pipeline/modules/redis').connect())
    .use(require('../qnectar/pipeline/modules/mongo').connect())

callosum_context.fns.alias = (inp, args, ctx, cb) ->
    alias = args[0]
    script = args[1]
    if !script
        # Showing an alias
        cb null, ctx.env.aliases[alias]
    else
        # Setting an alias
        ctx.alias alias, script
        cb null,
            success: true
            alias: alias
            script: script

        # Save in Redis
        redis.set 'aliases:' + alias, script

# Start the Callosum

callosum = null
start = ->
    callosum = new Callosum()

    # Get saved aliases
    bootstrap_redis_aliases = '''
        redis keys aliases:* @: {
            alias: $( split ":" @ 1 ),
            script: $( redis get $! )
        }
    '''
    pipeline.execPipelines bootstrap_redis_aliases, null, callosum_context, (err, saved_aliases) =>
        for alias in saved_aliases
            callosum_context.alias alias.alias, alias.script

setTimeout start, 500
