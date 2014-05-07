request = require 'request'
Client = require './client'

btcavg_url = 'https://api.bitcoinaverage.com/ticker/global/USD/'
get_btc_data = (cb) ->
    request.get {url: btcavg_url, json: true}, (err, res, data) ->
        cb err, data

btc_client = new Client
    name: "Bitcoin Tracker"
    commands:

        btc: (msg, cb) ->
            get_btc_data (err, data) ->

                # Send as event
                if msg.args[0] == 'check'
                    cb null, null,
                        type: 'event'
                        event: 'btc'
                        data: data

                # Regular response
                else
                    cb null, data

