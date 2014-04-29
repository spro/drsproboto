Client = require './client'
xmpp = require 'simple-xmpp'
config = require '../drsproboto_node/config'
{randomString, stringify} = require './helpers'

xmpp.connect config.xmpp

default_to = 'sprobertson@gmail.com'

xmpp.on 'online', ->
    xmpp.send default_to, 'The Doctor is in.'

pending_requests = {}

class XMPPClient extends Client
    name: 'xmpp'
    commands:
        xmpp: (msg, cb) ->
            console.log "Received " + msg.data
            receiver = msg.args[0]
            body = msg.summary || msg.data || msg.args.slice(1).join(' ')
            xmpp.send receiver, stringify body

xmpp_client = new XMPPClient

# Receiving a response
xmpp_client.on 'message', (msg) ->
    console.log msg
    sender = pending_requests[msg.id]
    console.log "Received a " + typeof msg.data
    body = msg.summary || msg.data || msg.error
    xmpp.send sender, stringify body

# Sending a script
# The sender is stored in `pending_requests` with
# the message id, the response is expected to have
# an equivalent `id`
xmpp.on 'chat', (sender, body) ->
    console.log "<#{ sender }> #{ body }"
    msg = xmpp_client.send
        type: 'script'
        script: body
    pending_requests[msg.id] = sender

