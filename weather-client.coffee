Client = require './client'
request = require 'request'
redis = require('redis').createClient()

default_zip = 94122
weatherURL = (zip) ->
    "http://api.wunderground.com/api/0521158dab6d17ce/conditions/q/CA/#{ zip }.json"

getWeather = (zip, cb) ->
    request.get {url: weatherURL(zip), json: true}, (err, res, weather_data) ->
        cb null, weather_data.current_observation

getCachedWeather = (zip=default_zip, cb) ->
    cache_key = 'weather-json:' + zip
    redis.get cache_key, (err, weather_json) ->

        if !weather_json
            getWeather zip, (err, weather_data) ->
                weather_json = JSON.stringify(weather_data)
                redis.setex cache_key, 120, weather_json
                cb null, weather_data

        else
            console.log '[getCachedWeather] using cached'
            cb null, JSON.parse weather_json

weather_client = new Client
    name: "Wunderground API Client"
    commands:
        
        'weather-json': (message, cb) ->
            getCachedWeather message.args?[0], cb
