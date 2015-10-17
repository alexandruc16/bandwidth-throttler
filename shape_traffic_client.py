import zmq

context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect("tcp://localhost:5555")
socket.send("set 10.0.0.2:10mbit")
message = socket.recv()
print "Received reply ",message
