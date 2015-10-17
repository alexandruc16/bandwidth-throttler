# bandwidth-throttler
A simple client-server architecture that allows a user to limit the bandwidth between machines.
The server needs to run on the machine whose incoming and outgoing traffic from and to a destination
you want throttled. The client can be run on any machine and issues throttling requests to specific
servers.

## Requirements
Relies on the following Python libraries:
* pyzmq 14.0.1
* psutil 2.1.0

## Usage
The server is run using the following command
```bash
python shape_traffic_server.py -p <port>
```
