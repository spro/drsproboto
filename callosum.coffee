zmq = require 'zmq'
{EventEmitter} = require 'events'
{randomString, log} = require './helpers'
_ = require 'underscore'
pipeline = require '../qnectar/pipeline/pipeline'
util = require 'util'
redis = require('redis').createClient()
coffee = require 'coffee-script'

VERBOSE = false
HEARTBEAT_INTERVAL = 5000
HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL * 5
REGISTRATION_TIMEOUT = HEARTBEAT_INTERVAL * 5

class Callosum

    pending_registrations: {}
    pending_commands: {}
    registered_clients: {}
    registered_handlers: {}
    triggers: []

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
        callosum_pipeline.exec save_message, message, (err, saved_message) => # ...

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

            when 'event'
                @handleEvent client_id, message

            else
                log 'Unrecognized message: ' + util.inspect message

    # SCRIPT messages are parsed and executed by the pipeline

    handleScript: (client_id, message) ->
        log "<#{ client_id }> → SCRIPT [#{ message.id }] #{ message.script }", color: 'cyan'
        callosum_pipeline.exec message.script, message.data, (err, data) =>
            if err
                log 'ERROR ' + err, color: 'red'
                @send client_id,
                    id: message.id
                    error: err.toString()
            else
                @send client_id,
                    id: message.id
                    data: data

    # COMMAND messages are sent to an appropriate handler; the ID of the 
    # message is stored in `pending_commands` for handling the RESPONSE

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

    # RESPONSE messages have an `rid` (response ID) to be looked up in
    # `pending_commands` and sent back to the requesting client (if commanded
    # via a message) or the stored callback called (if commanded through a pipeline)

    handleResponse: (client_id, message) ->
        log "<#{ client_id }> → RESPONSE [#{ message.rid }]", color: 'green'
        pending_command = @pending_commands[message.rid]
        if _.isFunction pending_command
            pending_command null, message.data
        else
            @send pending_command.origin, message
        delete @pending_commands[message.rid]

    # EVENT messages are stored and matched against the set of triggers

    handleEvent: (client_id, message) ->
        for trigger in @triggers
            if trigger.match message
                trigger.run message

    # Create a trigger to be run from the 
    # TODO: Save to redis like aliases

    addTrigger: (options) ->
        match_compiled = coffee.compile options.match, {bare: true}
        run_compiled = coffee.compile options.run, {bare: true}
        new_trigger =
            id: options.key.split(':').slice(1).join(':')
            match: (msg) -> eval match_compiled
            run: (msg) -> eval run_compiled
            match_raw: options.match
            run_raw: options.run
        @triggers.push new_trigger

    # When a COMMAND message is being handled, a handler must be selected from the
    # set of currently registered handlers.

    selectHandler: (command) ->
        if to_client_ids = @registered_handlers[command]
            # Get an available handler client
            to_client_id = to_client_ids.shift()
            to_client_ids.push to_client_id
            return to_client_id

    # See if there are any dead clients by comparing their last
    # heartbeat times to the timeout interval. 

    checkup: ->
        now = new Date().getTime()
        for client_id, client of @registered_clients

            # Check if it should be considered dead
            if (now - client.last_seen) > HEARTBEAT_TIMEOUT

                @unregisterClient client_id

    # Begin the checkup cycle

    startCheckups: ->
        setInterval (=> @checkup()), 500

# Extend the qnectar pipeline to look up functions
# in the set of registered handlers.

class CallosumPipeline extends pipeline.Pipeline
CallosumPipeline::get = (t, k) ->
    found = super
    if !found? and t == 'fns'
        if callosum.registered_handlers[k]?
            found = (inp, args, ctx, cb) =>
                # Do the thing
                to_client_id = callosum.selectHandler k
                command_message =
                    id: randomString 16
                    command: k
                    data: inp
                    args: args
                callosum.send to_client_id, command_message
                callosum.pending_commands[command_message.id] = cb
    return found

callosum_pipeline = new CallosumPipeline()
    .use('html')
    .use(require('../qnectar/pipeline/modules/redis').connect())
    .use(require('../qnectar/pipeline/modules/mongo').connect())

callosum_pipeline.alias = (a, s) ->
    # Default aliasing
    @set 'fns', a, pipeline.through s
    @set 'aliases', a, s

    # Save in Redis
    redis.set 'aliases:' + a, s

# Helper for running one-off scripts

runScript = (script, inp={}) ->
    callosum_pipeline.exec script, inp, (err, data) =>
        if err
            log 'ERROR ' + err, color: 'red'

# Start the Callosum

callosum = null
start = ->
    callosum = new Callosum()

    # Bootstrap saved aliases from Redis
    get_redis_aliases = '''
        redis keys aliases:* @: {
            alias: $( split ":" @ 1 ),
            script: $( redis get $! )
        }
    '''
    callosum_pipeline.exec get_redis_aliases, (err, saved_aliases) =>
        for alias in saved_aliases
            callosum_pipeline.alias alias.alias, alias.script

    # Bootstrap saved triggers from Redis
    get_redis_triggers = '''
        redis keys triggers:* @: { key: ., } || extend $( redis hgetall $( @ key ) )
    '''
    callosum_pipeline.exec get_redis_triggers, (err, saved_triggers) =>
        for trigger in saved_triggers
            callosum.addTrigger trigger

# Let the machinery warm up a bit
setTimeout start, 500

