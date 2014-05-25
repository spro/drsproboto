Client = require './client'
readline = require 'readline'
{log, stringify} = require './helpers'
os = require 'os'

class StdinClient extends Client
    name: 'stdin.' + os.hostname()

stdin_client = new StdinClient

# Print out a message error or response
log_message = (message) ->
    if message.error
        log '[ERROR] ' + stringify(message.error), color: 'red', date: false
    else
        log stringify(message.summary || message.data), color: 'green', date: false

# Execute single script if specified
if process.argv.length > 2
    script = process.argv.slice(2).join(' ')
    stdin_client.send
        type: 'script'
        script: script

    stdin_client.on 'message', (message) ->
        log_message message
        process.exit()

# Set up readline prompt
else
    stdin_client.on 'message', (message) ->
        log_message message
        rl.prompt()

    last_message = ''
    rl = readline.createInterface
        input: process.stdin
        output: process.stdout
    rl.setPrompt '> '
    rl.prompt()

    # Respeon
    rl.on 'line', (line) ->
        line = line.trim()
        message = null

        if line == '!!'
            message = last_message

        else
            message =
                type: 'script'
                script: line
            last_message = message

        stdin_client.send message

