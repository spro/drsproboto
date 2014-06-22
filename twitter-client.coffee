Client = require './client'
config = require './config'
util = require 'util'
Twitter = require 'twit'

twitter = new Twitter config.twitter

twitter_client = new Client
    name:'twitter',
    commands:
        tweet: (message, cb) ->
            status = message.args.join(' ')
            twitter.post 'statuses/update', {status: status}, (err, reply) ->
                console.log util.inspect reply
                cb null, "Tweeted: '#{ reply.text }'"

