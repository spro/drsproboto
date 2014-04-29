cheerio = require 'cheerio'
request = require 'request'
Client = require './client'
async = require 'async'
redis = require('redis').createClient()
minimist = require 'minimist'

# Build a sfbay craigslist URL out of parameters
craigslist_base = "http://sfbay.craigslist.org"
makeCraigslistURL = (cat, query) ->
    "#{ craigslist_base }/search/#{ cat }/sfc?query=#{ query.trim().replace(/\W+/, '+') }"

seen_ids = []

# Return an array of craigslist post objects
searchCraigslist = (cat, query, cb) ->
    request.get makeCraigslistURL(cat, query), (err, res, body) ->

        $ = cheerio.load body
        posts = []

        # Get each post row
        $rows = []
        $('.row[data-pid]').each ->
            $rows.push $(this)

        for $row in $rows
            
            # Avoid the "nearby" section
            if $row.hasClass 'ban'
                break

            # Build the post object
            new_post =
                id: Number $row.data('pid')
                title: $row.find('.pl a').text()
                url: craigslist_base + $row.find('.pl a').attr('href')
                city: $row.find('.l2 .pnr small').text().match(/\((.+)\)/)?[1]
                category: $row.find('.gc').text()

            posts.push new_post

        cb null, posts

# Turn array of craigslist posts into a message
postsSummary = (posts) ->
    post_texts = []
    for post in posts
        post_text = post.title
        post_text += ' (' + post.city + ')' if post.city?
        post_text += ': ' + post.url
        post_texts.push post_text
    post_texts.join('\n')

# Handle a craigslist command message, executing one of the sub-commands
# (search or check). Check is the same as search but saves post IDs to
# a Redis set to compare against, only returning those posts that have not
# been seen before.
#
# Optionally format the output into text with the `--summary` flag

handleCraigslistCommand = (message, cb) ->
    options = minimist message.args
    args = options._
    console.log options
    console.log args
    command = args.shift()

    # Respond with all posts
    if command == 'search'
        cat = args.shift()
        query = args.join(' ')
        searchCraigslist cat, query, (err, posts) ->
            if options.summary?
                posts_summary = postsSummary posts
                cb null, posts_summary
            else
                cb null, posts

    # Respond only with unseen posts
    if command == 'check'
        cat = args.shift()
        query = args.join(' ')
        searchCraigslist cat, query, (err, posts) ->

            new_posts = []
            post_is_new = (post, _cb) ->
                redis.sadd 'craigslist:post_ids', post.id, (err, added) ->
                    _cb added

            async.filter posts, post_is_new, (new_posts) ->
                if new_posts.length
                    if options.summary?
                        new_posts_summary = postsSummary new_posts
                        plural = if new_posts.length == 1 then '' else 's'
                        new_posts_summary = "New result#{ plural } for \"#{ query }\" in #{ cat }:\n" + new_posts_summary
                        cb null, new_posts_summary
                    else
                        cb null, new_posts

craigslist_client = new Client
    name: 'Craigslist watcher'
    commands:
        craigslist: handleCraigslistCommand

