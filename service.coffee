somata = require 'somata'

# Helpers

capitalize = (s) ->
    s[0].toUpperCase() + s.slice(1)

title = (s) ->
    s.split(' ').map(capitalize).join(' ')

randomChoice = (l) ->
    l[Math.floor Math.random()*l.length]

# Responses

re_word = "(\\w+)"
re_phrase = "([\\w\\s]+)"

weather_states = ['sunny', 'breezy', 'snowing', 'raining']
people = ['barack obama', 'nassir assad', 'chad lieberman', 'frederick jones']
metrics = ['100 million', '52', '1.005']
idk = ["I don't understand.", "I can't understand you.", "Not sure what you mean by that...", "I don't know what you're saying.", "What?"]

responses =
    "hello": """
        Hi there. I am Dr. Sproboto. You can call me @drsproboto.
        I can do a lot of things. Go ahead and ask me, "What can you do?"
    """

    "what can you do": """
        Oh I am so glad you asked. I can do a lot.
        I can set a reminder for you if you ask "Remind me to get the laundry in 35 minutes"
        I can tell you about the weather: "What is the weather in San Francisco?" or even the time: "What time is it in Japan?"
        Or ask the price of some asset, "What is the price of bitcoin?"
        Maybe it's getting late and you just want to "Turn off the office light" and "Turn the music down"
    """

    "what else can you do": """
        You're one of the curious ones. I'll make a note of that. There are some more complicated things I'm still learning...
        One thing is to send alerts when something happens, for example "Tell me when the door opens", or when the value of something passes a threshold, like "Let me know when the price of bitcoin is above 1200" or "Text me if the basement temperature is below 35"
        Instead of alerts I can trigger something else, like "Turn on the living room light when the door opens" or "Make the office light green when the bitcoin price is above 950" or even "Set all the lights red when the door opens if it is after 1am" Just kidding, I can't do that last one yet.
        There are also some random facts I have been learning from Wikipedia, like "Who is the president of North Korea?" or "What is the population of New York?"
    """

    "what time is it": ->
        "It is " + new Date().toString()

    "what is the weather in #{re_phrase}": (location) ->
        "In #{title location} it is " + randomChoice weather_states

    "who is the #{re_word} of #{re_phrase}": (position, location) ->
        if Math.random() < 0.3
            "I don't know who the #{position} of #{title location} is"
        else
            "The #{position} of #{title location} is " + title randomChoice people

    "what is the #{re_word} of #{re_phrase}": (metric, location) ->
        if Math.random() < 0.3
            "I don't know the #{metric} of #{title location}"
        else
            "The #{metric} of #{title location} is " + randomChoice metrics

    "remind me to #{re_phrase} in #{re_phrase}": (reminder, time) ->
        "I will remind you to #{reminder} in #{time}."

    "find songs by #{re_phrase}": (artist) ->
        "Here are #{Math.floor Math.random()*10} songs by #{title artist}... just kidding I can't do that yet."

    "turn #{re_word} the #{re_phrase}": (state, device) ->
        "Ok, I turned #{state} the #{device}."

Object.entries = (o) ->
    entries = []
    for k, v of o
        entries.push [k, v]
    entries

matchResponse = (input) ->
    for match, response of responses
        if matched = input.match new RegExp match
            if typeof response == 'function'
                response = response(matched.slice(1)...)
            return response

new somata.Service 'drsproboto',
    parse: (input, cb) ->
        input = input.trim().toLowerCase().replace(/[^a-z0-9 ]/g, '')
        if response = matchResponse input
            cb null, response
        else
            cb null, randomChoice idk
