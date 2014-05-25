brain = require 'brain'
request = require 'request'
redis = require 'redis'

zip = 94122
weather_url = "http://api.wunderground.com/api/0521158dab6d17ce/conditions/q/CA/#{ zip }.json"
guessSweater = (cb) ->
    request.get {url: weather_url, json: true}, (err, res, weather_data) ->
        o = weather_data.current_observation
        weather_vector =
            f: Number(o.temp_f)/100
            w: Number(o.wind_mph)/100
            r: Number(o.precip_1hr_metric)/100
        console.log weather_vector
        cb null, nn.run weather_vector

inputs = [
    input: {f: 66/100, w: 0/100, r: 0}
    output: {sweater: 0}
,
    input: {f: 76/100, w: 5/100, r: 0}
    output: {sweater: 0}
,
    input: {f: 86/100, w: 2/100, r: 0}
    output: {sweater: 0}
,
    input: {f: 76/100, w: 10/100, r: 0}
    output: {sweater: 0}
,
    input: {f: 66/100, w: 5/100, r: 0}
    output: {sweater: 1}
,
    input: {f: 56/100, w: 0/100, r: 0}
    output: {sweater: 1}
,
    input: {f: 60/100, w: 10/100, r: 5/100}
    output: {sweater: 1}
,
    input: {f: 50/100, w: 0/100, r: 0}
    output: {sweater: 1}
]

nn = new brain.NeuralNetwork()
nn.train inputs

#console.log nn.run {f: Number(process.argv[2])/100, w: Number(process.argv[3])/100}
guessSweater (err, sweater_vector) ->
    console.log sweater_vector

