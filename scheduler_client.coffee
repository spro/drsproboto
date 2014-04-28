Client = require './client'
db_conn = new (require 'nosqlite').Connection './data'
db = db_conn.database('events')
db.exists (exists) -> db.create() if !exists
util = require 'util'
_ = require 'underscore'

scheduler_client = new Client
    name: 'Scheduler'

    commands:

        at: (message, cb) ->
            matched = message.args.join(' ').match /^([0-9:]+) (.*)/
            if not matched
                cb "Don't quite know what you mean."
                return
            t = matched[1].split(':')
            t_h = Number t[0]
            t_m = if t.length > 1 then Number t[1] else 0
            t_s = if t.length > 2 then Number t[2] else 0
            now = new Date()
            script = matched[2]
            new_event =
                message:
                    id: message.id
                    type: 'script'
                    script: message.args.slice(1).join(' ')
                time: (new Date(now.getFullYear(), now.getMonth(), now.getDate(), t_h, t_m, t_s)).getTime()
            db.post new_event, (err, id) ->
                cb null, "Should send message at #{ new Date(new_event.time) }"

        in: (message, cb) ->
            matched = message.args.join(' ').match /^(\d+) ?(\w+) (.*)/
            if not matched
                cb "Don't quite know what you mean."
                return
            t = Number matched[1]
            tt = matched[2]
            script = matched[3].split(' ')
            if tt.match /^h/
                dt = t * 1000 * 60 * 60
            if tt.match /^m/
                dt = t * 1000 * 60
            if tt.match /^s/
                dt = t * 1000
            new_event =
                message:
                    id: message.id
                    origin: message.origin
                    type: 'script'
                    script: message.args.slice(1).join(' ')
                time: (new Date()).getTime() + dt
            console.log "the origin is " + message.origin
            db.post new_event, (err, id) ->
                cb null, "Should send message at #{ new Date(new_event.time) }"

        every: (message, cb) ->
            if matched = message.args.join(' ').match /^(\d+) ?(\w+) (.*)/
                # Create a new scheduled message with an interval
                t = Number matched[1]
                tt = matched[2]
                script = matched[3].split(' ')
                if tt.match /^h/
                    dt = t * 1000 * 60 * 60
                if tt.match /^m/
                    dt = t * 1000 * 60
                if tt.match /^s/
                    dt = t * 1000
                new_event =
                    message: message
                    time: (new Date()).getTime() + dt
                    interval: dt
                    interval_raw: matched.slice(1, 3).join('')
                db.post new_event, (err, id) ->
                    cb null, "Should send message at #{ new Date(new_event.time) }"

            # Cancel a message
            else if matched = message.args.join(' ').match /^cancel (\w+)/
                id = matched[1]
                db.delete id, (err) ->
                    cb null, "Canceled scheduled message #{ id }."

            # List scheduled messages
            else if message.args.join(' ').match /^list/
                console.log 'Listing scheduled messages'
                event_texts = []
                db.all (err, events) ->
                    for event in events
                        event_texts.push "#{ event.id }: `#{ event.command }` every #{ event.interval_raw }"
                    cb null, null,
                        body: event_texts.join '\n'
                        data: events

            else
                cb "Don't quite know what you mean."

run_event = (event) ->
    scheduler_client.send event.message

    if event.interval?
        event_update = time: (new Date()).getTime() + event.interval
        db.put event.id, event_update, (err, id) ->
            console.log "Rescheduled message."

    else
        db.delete event.id, ->
            console.log "Deleted scheduled message."

check_events = ->
    db.all (err, events) ->
        for event in events
            if event.time < new Date().getTime()
                run_event event

setInterval check_events, 1000

