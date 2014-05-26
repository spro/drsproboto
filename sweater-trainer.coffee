Client = require './client'
brain = require 'brain'
_ = require 'underscore'
util = require 'util'
async = require 'async'

getWeatherVector = (cb) ->
    sweater_client.runScript 'weather-json', (err, o) ->
        weather_vector =
            f: Number(o.temp_f)/100
            w: Number(o.wind_mph)/100
            r: Number(o.precip_1hr_metric)/100
        console.log '[getWeatherVector] ' + util.inspect weather_vector
        cb null, weather_vector

guessSweater = (cb) ->
    getWeatherVector (err, weather_vector) ->
        cb null, _.extend weather_vector, nn.run weather_vector

getTrainingPatterns = (cb) ->
    sweater_client.runScript 'redis smembers sweater:training', (err, _data) ->
        cb null, _data.map (d) -> JSON.parse d

trainSweater = (sweater, cb) ->
    getWeatherVector (err, weather_vector) ->
        pattern =
            input: weather_vector
            output: {sweater: sweater}
        trainPattern pattern, (err, trained) ->
            getTrainingPatterns (err, patterns) ->
                nn.train patterns
                cb null, "Trained."

trainPattern = (pattern, cb) ->
    sweater_client.runScript 'redis sadd sweater:training $!', JSON.stringify(pattern), cb

sweater_client = new Client
    name: "Sweater Trainer"
    commands:
        
        'sweater-yes': (msg, cb) ->
            trainSweater 1.0, cb

        'sweater-no': (msg, cb) ->
            trainSweater 0.0, cb

        'sweater': (msg, cb) ->
            guessSweater (err, sweater_vector) ->
                cb null, sweater_vector

# Create and train neural network
nn = new brain.NeuralNetwork()
getTrainingPatterns (err, patterns) ->

    if !patterns.length
        console.log 'Bootstrapping training data...'

        # Bootstrap with two anchor patterns
        patterns = [
            input: {f: 80/100, w: 0/100, r: 0}
            output: {sweater: 0}
        ,
            input: {f: 40/100, w: 0/100, r: 0}
            output: {sweater: 1}
        ]

        async.map patterns, (pattern, cb) ->
            trainPattern pattern, cb
        , (err, oks) ->
            nn.train patterns
            console.log "Trained network with bootstrap data."

    else
        nn.train patterns
        console.log "Trained network with existing data."

# if module.name == 'main'
#     console.log nn.run {f: Number(process.argv[2])/100, w: Number(process.argv[3])/100}
