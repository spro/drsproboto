Client = require './client'
config = require './config'

h = new Client
    name: 'Worrying about the time guy'

setInterval ->
    h.send
        command: 'log'
        data: new Date()
, 1500

