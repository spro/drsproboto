Client = require './client'

histogram_client = new Client
    name: 'Histogram Client'
    commands:
        histogram: (message, cb) ->
            cb null, make_histogram message.data

padded = (s, n=15) ->
    make_padding(n - s.length) + s

make_padding = (n) ->
    (' ' for i in [0..n]).join('')

make_histogram = (l, x='#') ->
    rows = []
    for n in l
        if typeof n == 'object'
            r = padded n.item + ' '
            n = n.count
        else
            r = ''
        for i in [0..n]
            r += x
        rows.push r
    rows.join '\n'

