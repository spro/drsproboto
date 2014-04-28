moment = require 'moment'

date_format = 'YYYY-MM-DD hh:mm:ss'
exports.log = (s) ->
    console.log "[#{ moment().format(date_format) }] #{ s }"

exports.randomString = (len=5) ->
    s = ''
    while s.length < len
        s += Math.random().toString(36).slice(2, len-s.length+2)
    return s

