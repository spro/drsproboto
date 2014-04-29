Client = require './client'
{exec} = require 'child_process'

notification_client = new Client
    name: 'Notification Client'
    commands:
        notify: (message, cb) ->
            exec "terminal-notifier -title 'Dr. Sproboto' -message '#{ message.args.join(' ').replace("'", "\\'") }'"
            console.log 'test'
            cb null, 'Notified.'


