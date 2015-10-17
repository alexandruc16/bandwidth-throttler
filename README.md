# bandwidth-throttler
A simple client-server architecture that allows a user to limit the bandwidth between machines.
The server needs to run on the machine whose incoming and outgoing traffic from and to a destination
you want throttled. The client can be run on any machine and issues throttling requests to specific
servers.

## Requirements
Relies on the following Python libraries:
* pyzmq 14.0.1
* psutil 2.1.0

Additionally, the server needs to have root rights, because of the underlying mechanism of
actually restricting the bandwidth.


## Usage
The server is run using the following command:
```bash
python shape_traffic_server.py --port <port>
```
The client can be run in two ways, either:
```bash
python shape_traffic_client.py --port <port> --set <ip1>:<ip2>:<bandwidth>
```
to limit the traffic between two machines, or:
```bash
python shape_traffic_client.py --port <port> --set-file <filename>
```
to limit the traffic between multiple machines. Each line in the file should
have the same syntax as the set command.
