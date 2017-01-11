qrepl = require 'qrepl'
somata = require 'somata'
client = new somata.Client

qrepl 'drsproboto', (line, cb) ->
    input = line.trim().toLowerCase()
    client.remote 'drsproboto', 'parse', input, cb

