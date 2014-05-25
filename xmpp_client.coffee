Client = require './client'
xmpp = require 'simple-xmpp'
config = require '../drsproboto_node/config'
{log, randomString, stringify} = require './helpers'

xmpp.connect config.xmpp

xmpp.on 'online', ->
    xmpp.send config.xmpp.default_receiver, 'The Doctor is in.'

pending_requests = {}

class XMPPClient extends Client
    name: 'xmpp'
    commands:
        xmpp: (msg, cb) ->
            receiver = msg.args[0]
            if buddy_alias = config.xmpp.buddies[receiver]
                receiver = buddy_alias
            if !receiver
                receiver = config.xmpp.default_receiver
            body = msg.summary || msg.data || msg.args.slice(1).join(' ')
            xmpp.send receiver, stringify body
            cb null, success: true

xmpp_client = new XMPPClient

# Receiving a response
xmpp_client.on 'message', (msg) ->
    sender = pending_requests[msg.id]
    body = msg.summary || msg.data || msg.error
    xmpp.send sender, stringify body

# Sending a script
# The sender is stored in `pending_requests` with
# the message id, the response is expected to have
# an equivalent `id`
xmpp.on 'chat', (sender, body) ->
    log "<#{ sender }> #{ body }", color: 'cyan'
    msg = xmpp_client.send
        type: 'script'
        script: body
    pending_requests[msg.id] = sender

