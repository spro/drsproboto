React = require 'react'
ReactDOM = require 'react-dom'
ReactContenteditable = require 'react-contenteditable'
somata = require 'somata-socketio-client'
reactStringReplace = require 'react-string-replace'
ReactCSSTransitionGroup = require 'react-addons-css-transition-group'
KefirBus = require 'kefir-bus'
KefirCollection = require 'kefir-collection'

somata.subscribe 'reloader', 'reload', -> window.location = window.location

initial_messages = [
    {
        _id: 0
        sender: 'drsproboto'
        body: """
            Hi there, I am Dr. Sproboto. You can call me @drsproboto. I know how to do a few useful things...

            So go ahead and ask me: "What can you do?"
        """
    }
    {
        _id: 1
        sender: 'drsproboto'
        body: """
            Oh I am so glad you asked. I can do a lot.
            I can set a reminder for you if you ask "Remind me to get the laundry in 35 minutes"
            I can tell you about the weather: "What is the weather in San Francisco?" or even the time: "What time is it in Japan?"
            Or ask the price of some asset, "What is the price of bitcoin?"
            Maybe it's getting late and you just want to "Turn off the office light" and "Turn the music down"
        """
    }
    {
        _id: 2
        sender: 'drsproboto'
        body: """
            You're one of the curious ones. I'll make a note of that. There are some more complicated things I'm still learning...

            One thing is to send alerts when something happens, for example "Tell me when the door opens", or when the value of something passes a threshold, like "Let me know when the price of bitcoin is above 1200" or "Text me if the basement temperature is below 35"

            Instead of alerts I can trigger something else, like "Turn on the living room light when the door opens" or "Make the office light green when the bitcoin price is above 950" or even "Set all the lights red when the door opens if it is after 1am" Just kidding, I can't do that last one yet.

            There are also some random facts I have been learning from Wikipedia, like "Who is the president of North Korea?" or "What is the population of New York?"
        """
    }
    {
        _id: 3
        sender: 'drsproboto'
        body: "The temperature in San Diego is 72ºF"
    }
    {
        _id: 4
        sender: 'drsproboto'
        body: "Right now it is 3:03PM in Tokyo, Japan"
    }
    {
        _id: 5
        sender: 'drsproboto'
        body: "The president of North Korea is Chad Lieberman"
    }
    {
        _id: 6
        sender: 'drsproboto'
        body: "Ok, turned on the office light."
    }
    {
        _id: 7
        sender: 'drsproboto'
        body: "Next time bitcoin is above 950 I will turn the office light green."
    }
]


messages$ = KefirCollection([], id_key: '_id')
sent_message$ = KefirBus()

sendMessage = (m) ->
    sent_message$.emit {
        _id: Math.floor Math.random() * 9999 + 100
        sender: 'spro'
        body: m
    }

ii = 1

sent_message$.onValue (message) ->
    ii += 1
    messages$.createItem message
    setTimeout ->
        messages$.createItem {_id: ii, sender: 'drsproboto'}
        somata.remote 'drsproboto', 'parse', message.body, (err, next_message) ->
            nm = next_message.length * 2
            sendNext = ->
                messages$.updateItem ii, {body: next_message}
            setTimeout sendNext, nm
    , 200

messages$.createItem initial_messages[0]

NewMessage = React.createClass
    getInitialState: ->
        body: ''

    onChange: (e) ->
        body = e.target.value
        @setState {body}

    sendMessage: (e) ->
        e?.preventDefault()
        sendMessage @state.body
        @setState @getInitialState()

    onKeyDown: (e) ->
        if e.key == 'Enter'
            e.preventDefault()
            @sendMessage()

    render: ->
        <form className='new-message' onSubmit=@sendMessage>
            <img src='/images/human.png' />
            <ReactContenteditable html=@state.body onChange=@onChange onKeyDown=@onKeyDown />
            <button onClick=@sendMessage>Send</button>
        </form>

PlaceholderMessage = ->
    <div className='placeholder-message'>
        <img src='/images/drsproboto.png' />
        . . .
    </div>

App = React.createClass
    getInitialState: ->
        messages: []

    componentDidMount: ->
        messages$.onValue @setMessages
        @fixScroll()

    setMessages: (messages) ->
        @setState {messages}, @fixScroll

    filterMessages: (filter) ->
        messages = @state.messages
        messages = messages.filter filter
        @setState {messages}, @fixScroll

    sendMessage: (m) -> ->
        m = m.replace /"/g, ''
        sendMessage m

    fixScroll: ->
        document.body.scrollTop = document.body.scrollHeight

    render: ->
        <div className='messages'>
            <ReactCSSTransitionGroup
                transitionName="message-animation"
                transitionEnterTimeout=500
                transitionLeaveTimeout=10
            >
            {@state.messages.map (message) =>
                <div className={'message ' + message.sender} key=message._id>
                    {if message.sender == 'drsproboto'
                        <img src='/images/drsproboto.png' />
                    else
                        <img src='/images/human.png' />
                    }
                    {if !message.body?
                        <em className='pending'>...</em>
                    else
                        message.body.split('\n').map (line, li) =>
                            <p className=li>
                                {replaced = reactStringReplace line, /("[^"]+?")/g, (match, mi) =>
                                    <a key=mi onClick={@sendMessage(match)}>{match}</a>
                                replaced = reactStringReplace replaced, /(@\w+)/g, (match, mi) =>
                                    <a key=mi onClick={@sendMessage(match)}>{match}</a>
                                replaced
                                }
                            </p>
                    }
                </div>
            }
            </ReactCSSTransitionGroup>
            <NewMessage />
        </div>

ReactDOM.render <App />, document.getElementById 'app'
