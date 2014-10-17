Client = require './client'
express = require 'express'
util = require 'util'
ansi = require('ansi')(process.stdout)

client = new Client
    name: 'webhook client'

log_req = (req) ->
    switch req.method
        when 'GET'
            ansi.fg.green()
    ansi.write('[' + req.method + '] ')
    ansi.reset()
    ansi.write req.url + '\n'

app = express()
app.use express.bodyParser()
app.use (req, res, next) ->
    log_req req
    next()
app.use app.router

# Hook for sending events
# TODO: Implement scripts & commands
app.post '/events/:event_type', (req, res) ->
    event_type = req.params.event_type
    event_data = req.body
    client.send
        type: 'event'
        event: event_type
        data: event_data
    res.end 'ok'

app.get '/events/:event_type', (req, res) ->
    event_type = req.params.event_type
    event_data = JSON.parse req.query.message
    client.send
        type: 'event'
        event: event_type
        data: event_data
    res.end 'ok'

app.listen 5010, -> console.log "Webhook server listening on :5010"

