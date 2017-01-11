ss = require 'somata-socketio'

app = ss port: 3420

app.get '/', (req, res) -> res.render 'index'

app.start()
