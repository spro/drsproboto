http = require 'http'
util = require 'util'
formidable = require 'formidable'
twilio = require 'twilio'
config = require './config'
Client = require './client'
wordwrap = require './utils/wordwrap'

twilio_api = twilio(config.twilio.account_sid, config.twilio.auth_token)

twilio_client = new Client
    name: 'Twilio Client'
    commands:

        # Make a call
        call: (msg, cb) ->
            call_to = msg.args[0]
            call_say = msg.args.slice(1).join(' ')

            twilio_api.makeCall
                to: call_to
                from: config.twilio.number
                url: config.twilio.say_url + encodeURIComponent call_say
            , (err, response) ->
                if err
                    console.log 'Error making Twilio call:'
                    console.log err
                    cb err
                else
                    cb null, succes: true

        # Send an SMS
        sms: (msg, cb) ->
            sms_to = msg.args[0]
            sms_text = msg.args.slice(1).join(' ')
            chunks = wordwrap sms_text, 155

            for i in [0..chunks.length-1]
                leader = if chunks.length > 1 then "#{ i+1 }/#{ chunks.length } " else ''
                twilio_api.sendSms
                    to: sms_to
                    from: config.twilio.number
                    body: leader + chunks[i]
                , (err, response) ->
                    if err
                        console.log 'Error sending Twilio SMS:'
                        console.log err
                        cb err
                    else
                        cb null, succes: true

server = http.createServer (req, res) ->
    if req.url == '/text'
        form = new formidable.IncomingForm()
        form.parse req, (err, fields, files) ->
            twilio_client.send
                script: fields.Body
                sender: 'twilio:' + fields.From

    else if req.url == '/voice'
        resp = new twilio.TwimlResponse()
        res.setHeader 'Content-Type', 'text/xml'
        resp.say('Hello. You have reached Doctor Sprobawto. Please enter some numbers and press pound.')
            .gather
                action: '/gathered'
        res.end resp.toString()

    else if req.url == '/gathered'
        resp = new twilio.TwimlResponse()
        res.setHeader 'Content-Type', 'text/xml'
        form = new formidable.IncomingForm()
        form.parse req, (err, fields, files) ->
            resp.say('Interesting that you would choose ' + fields.Digits + '... are you from ' + fields.FromCity + '? If so please please me by pressing 1 and then pound.')
                .gather
                    action: '/laststep'
            res.end resp.toString()

    else if req.url == '/laststep'
        resp = new twilio.TwimlResponse()
        res.setHeader 'Content-Type', 'text/xml'
        form = new formidable.IncomingForm()
        form.parse req, (err, fields, files) ->
            if (Number fields.Digits) == 1
                resp.say("Fantastic work don't you think?")
            else
                resp.say("Well computers are only as good as their programmers.")
            resp.say("Hmm. I guess this is goodbye.")
            res.end resp.toString()

    else if req.url.split('/')[1] == 'say'
        resp = new twilio.TwimlResponse()
        res.setHeader 'Content-Type', 'text/xml'
        to_say = decodeURIComponent req.url.split('/')[2]
        resp.say(to_say)
        res.end resp.toString()

    else
        resp = new twilio.TwimlResponse()
        res.setHeader 'Content-Type', 'text/xml'
        resp.say "I ain't understand that."
        res.end resp.toString()

server.listen 5603, '0.0.0.0', -> console.log 'Twilio webhooks listening.'

