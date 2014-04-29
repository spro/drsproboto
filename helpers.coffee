moment = require 'moment'
_ = require 'underscore'
util = require 'util'

date_format = 'YYYY-MM-DD hh:mm:ss'
exports.log = (s) ->
    console.log "[#{ moment().format(date_format) }] #{ s }"

exports.randomString = (len=5) ->
    s = ''
    while s.length < len
        s += Math.random().toString(36).slice(2, len-s.length+2)
    return s

exports.stringify = (o) ->
    if _.isString o
        return o
    else if _.isObject o
        return util.inspect o
    else if !o?
        return '(empty message)'
    else
        return o

