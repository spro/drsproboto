Client = require './client'
request = require 'request'
_ = require 'underscore'

wikiCase = (s) -> s.replace /\W+/, '_'
wikiURL = (q) ->
    "http://en.wikipedia.org/wiki/" + wikiCase q
wikiAPIURL = (q) ->
    "http://en.wikipedia.org/w/api.php?format=json&action=query&prop=extracts&explaintext&titles=" + wikiCase q

wiki_client = new Client
    name: 'Wikipedia Client'
    commands:
        wiki: (message, cb) ->

            # Fetch extracts
            request.get
                url: wikiAPIURL message.args.join(' ')
                json: true
            , (err, res, data) ->

                # Format results
                pages = _.values(data.query.pages)
                extracts = pages.map (page) ->
                    page.extract.split('\n').filter((i) -> i)[0] + '\n' + wikiURL page.title

                cb null, extracts.join('\n')

