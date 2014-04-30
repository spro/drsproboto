Client = require './client'
readline = require 'readline'
{log, stringify} = require './helpers'
os = require 'os'

class StdinClient extends Client
    name: 'stdin.' + os.hostname()

stdin_client = new StdinClient
stdin_client.on 'message', (message) ->
    if message.error
        log '[ERROR] ' + stringify(message.error), color: 'red', date: false
    else
        log stringify(message.summary || message.data), color: 'green', date: false
    rl.prompt()

last_message = ''
rl = readline.createInterface
    input: process.stdin
    output: process.stdout
rl.setPrompt '> '
rl.prompt()

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

