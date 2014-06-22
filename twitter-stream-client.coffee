Client = require './client'
async = require 'async'
config = require '../drsproboto_node/config'
_ = require 'underscore'
ansi = require('ansi')(process.stdout)
Twitter = require 'twit'

twitter = new Twitter config.twitter

watching = []
ignoring = []

keyword_stream = false
user_stream = false

restartStream = ->
    keyword_stream.stop() if keyword_stream
    user_stream.stop() if user_stream
    startStream()

startStream = ->
    track_keywords = watching.filter (k) -> k[0] != '@'
    track_users = watching.filter((k) -> k[0] == '@')

    # Watch keywords
    if track_keywords.length > 0
        console.log "Tracking keywords: " + track_keywords.join(', ')
        keyword_stream = twitter.stream 'statuses/filter',
            track: track_keywords.join(',')
            language: 'en'
        keyword_stream.on 'tweet', printAndSendTweet

    # Watch users
    if track_users.length > 0
        console.log "Tracking users: " + track_users.join(', ')
        async.map track_users, getUserId, (err, user_ids) ->
            console.log "User IDs: " + user_ids.join(', ')
            user_stream = twitter.stream 'statuses/filter',
                follow: user_ids.join(',')
                language: 'en'
            user_stream.on 'tweet', printAndSendTweet

    # Show ignoring
    console.log "Ignoring keywords: " + ignoring.join(', ')

getUserId = (screen_name, cb) ->
    twitter.get 'users/lookup', {screen_name: screen_name.slice(1)}, (err, users) ->
        user = users[0]
        cb err, user.id

# Output and send tweet as event
printAndSendTweet = (tweet) ->
    return false if shouldIgnore tweet

    summary = tweet.user.screen_name + ': ' + tweet.text

    ansi
        .bold().write(tweet.user.screen_name)
        .reset().write(' ' + tweet.text + '\n')

    twitter_stream_client.send
        type: 'event'
        event: 'tweet'
        data: tweet
        summary: summary

shouldIgnore = (tweet) ->
    for ignore in ignoring
        if tweet.text.toLowerCase().match ignore
            console.log "Ignoring: " + tweet.text
            return true
    return false

# Get saved keywords
makeKeyword = (s) -> s.toLowerCase().replace(/[^\w@]+/g, '+')

loadWatching = (cb) ->
    twitter_stream_client.runScript 'redis smembers twitter_stream:watching', cb

addWatching = (new_watching, cb) ->
    twitter_stream_client.runScript 'redis sadd twitter_stream:watching $!', new_watching, (err, n_added) ->
        loadWatching cb

removeWatching = (old_watching, cb) ->
    twitter_stream_client.runScript 'redis srem twitter_stream:watching $!', old_watching, (err, n_removed) ->
        loadWatching cb

loadIgnoring = (cb) ->
    twitter_stream_client.runScript 'redis smembers twitter_stream:ignoring', cb

addIgnoring = (new_ignoring, cb) ->
    twitter_stream_client.runScript 'redis sadd twitter_stream:ignoring $!', new_ignoring, (err, n_added) ->
        loadIgnoring cb

removeIgnoring = (old_ignoring, cb) ->
    twitter_stream_client.runScript 'redis srem twitter_stream:ignoring $!', old_ignoring, (err, n_removed) ->
        loadIgnoring cb

# Control the stream client by `watch`ing or `unwatch`ing keywords
# A list of current keywords can be obtained with `watching`

twitter_stream_client = new Client
    name: 'Twitter Stream Observer'
    commands:

        'twitter-watching': (msg, cb) ->
            cb null, null,
                summary: 'Watching: ' + watching.join(', ')
                data: watching

        'twitter-watch': (msg, cb) ->
            new_watching = msg.args.map makeKeyword
            addWatching new_watching, (err, _watching) ->
                watching = _watching
                restartStream()
                cb null, null,
                    summary: 'Now watching: ' + watching.join(', ')
                    data: watching

        'twitter-unwatch': (msg, cb) ->
            old_watching = msg.args.map makeKeyword
            removeWatching old_watching, (err, _watching) ->
                watching = _watching
                restartStream()
                cb null, null,
                    summary: 'Now watching: ' + watching.join(', ')
                    data: watching

        'twitter-ignore': (msg, cb) ->
            new_ignoring = msg.args.map makeKeyword
            addIgnoring new_ignoring, (err, _ignoring) ->
                ignoring = _ignoring
                cb null, null,
                    summary: 'Now ignoring: ' + ignoring.join(', ')
                    data: ignoring

        'twitter-unignore': (msg, cb) ->
            old_ignoring = msg.args.map makeKeyword
            removeIgnoring old_ignoring, (err, _ignoring) ->
                ignoring = _ignoring
                cb null, null,
                    summary: 'Now ignoring: ' + ignoring.join(', ')
                    data: ignoring

# Bootstrap and start streams
loadWatching (err, _watching) ->
    watching = _watching

    loadIgnoring (err, _ignoring) ->
        ignoring = _ignoring

        startStream()

