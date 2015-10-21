'''
Simple client that is able to issue bandwidth throttling requests
to other machines.
'''
import zmq
import argparse
import sys

'''
Actually sends a throttle request to the given destination, telling
it to limit bandwidth for a given IP to the given value.
'''
def send_throttle_request(destination, throttle_ip, bandwidth):
	context = zmq.Context()
	socket = context.socket(zmq.REQ)
	socket.connect("tcp://" + destination + ":" + args.port)
	socket.send("set " + throttle_ip + ":" + bandwidth)
	message = socket.recv()
	print "Received reply ",message

# We either want an individual command or a file that contains commands.
parser = argparse.ArgumentParser()
group = parser.add_mutually_exclusive_group(required = True)
group.add_argument("--set", help = "throttle the bandwidth between machines: <ip1>:<ip2>:<bandwidth>")
group.add_argument("--set-file", help = "the given file specifies the bandwidth between machines. See --set for the correct syntax")
parser.add_argument("--port", help = "The port on the server that the client connects to", required = True)
args = parser.parse_args()

# Limit a single link.
if args.set:
	parts = args.set.split(":")
	if len(parts) < 3:
		parser.print_usage()
		sys.exit()
	send_throttle_request(parts[0], parts[1], parts[2])

# Limit one or multiple links in the given file.
elif args.set_file:
	f = open(args.set_file, "r")
	for line in f:
		parts = line.split(":")
		if len(parts) < 3:
			print("Invalid line, skipping request: " + line)
		else:
			# Both ends need traffic shaping.
			send_throttle_request(parts[0], parts[1], parts[2])
			send_throttle_request(parts[1], parts[0], parts[2])
	f.close()

