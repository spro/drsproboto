Client = require './client'
brain = require 'brain'
_ = require 'underscore'

guessSweater = (cb) ->
    sweater_client.runScript 'weather-json', (err, o) ->
        weather_vector =
            f: Number(o.temp_f)/100
            w: Number(o.wind_mph)/100
            r: Number(o.precip_1hr_metric)/100
        console.log weather_vector
        cb null, _.extend weather_vector, nn.run weather_vector

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
sweater_client = new Client
    name: "Sweater Trainer"
    commands:
        
        sweater: (msg, cb) ->
            guessSweater (err, sweater_vector) ->
                cb null, sweater_vector

