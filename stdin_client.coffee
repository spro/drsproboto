readline = require 'readline'
Client = require './client'
os = require 'os'

class StdinClient extends Client
    name: 'stdin.' + os.hostname()

stdin_client = new StdinClient
stdin_client.on 'message', (message) ->
    console.log message.summary || message.data
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
        parts = line.split(' ')
        message =
            command: parts[0]
            data: parts[1..].join(' ')
        last_message = message

    stdin_client.send message

