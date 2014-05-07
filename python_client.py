import zmq
import random, string
context = zmq.Context()

# Helper for making an ID string
letters = string.lowercase + string.digits
def random_string(n):
    return ''.join([random.choice(letters) for i in range(n)])

# Decide some configuration
client_id = random_string(16)
server_addr = 'tcp://localhost:5003'

# Define the commands
commands = {
    'echo3': lambda args: ' '.join(args),
    'double': lambda args: args[0] + args[0],
    'square': lambda args: args[0] * args[0],
    'sum': lambda args: sum(args),
}

# Send a "register" message
def send_register():
    msg = {
        'type': 'register',
        'args': {
            'id': client_id,
            'name': 'Python Echoer',
            'handlers': commands.keys(),
        }
    }
    sock.send_json(msg)

# Send a "heartbeat" message
def send_heartbeat():
    msg = {
        'type': 'heartbeat',
        'args': {
            'id': client_id,
        }
    }
    sock.send_json(msg)

# Send a response to a command
def send_response(id, data):
    msg = {
        'type': 'response',
        'rid': id,
        'data': data,
    }
    print "Sending response: %s" % msg
    sock.send_json(msg)

# Handle a command message
def handle_msg(msg):
    print "Received message: %s" % msg
    data = commands[msg['command']](msg['args'])
    send_response(msg['id'], data)

# Create the client's socket and connect to the server
sock = context.socket(zmq.DEALER)
sock.setsockopt(zmq.IDENTITY, client_id)
sock.connect(server_addr)
print "%s connected to %s" % (client_id, server_addr)

# Set up a poller
poll = zmq.Poller()
poll.register(sock, zmq.POLLIN)

# Register
send_register()

# Poll periodically, handle new messages as they arrive
# Send a heartbeat at the end
while True:
    socks = dict(poll.poll(1000))

    if (sock in socks) and (socks[sock] == zmq.POLLIN):
        msg = sock.recv_json()
        handle_msg(msg)

    send_heartbeat()

