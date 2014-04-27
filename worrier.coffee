Handler = require './module'
config = require './config'

h = new Handler
    name: 'Worrying about the time guy'

setInterval ->
    h.send
        command: 'log'
        data: new Date()
, 1500

