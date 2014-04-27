moment = require 'moment'

date_format = 'YYYY-MM-DD hh:mm:ss'
exports.log = (s) ->
    console.log "[#{ moment().format(date_format) }] #{ s }"

exports.randomString = (len=5) ->
    Math.random().toString(36).slice(2, len+2)

