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
It expects the contents of `shape_traffic.sh` to be in `/usr/bin/shape_traffic`

The client can be run in various ways, for instance:
```bash
python shape_traffic_client.py --port <port> --set <ip1>:<ip2>:<bandwidth>
```
This will limit the traffic between two machines, or:
```bash
python shape_traffic_client.py --port <port> --set-file <filename>
```
which limits the traffic between multiple machines. Each line in the file should
have the same syntax as the set command.

You can also use the client to uniformly generate bandwidth values between certain links:
```bash
python shape_traffic_client.py --generate-uniform <ip1>:<ip2>:.. <bw1>:<bw2>:.. <output_file>
```
This will generate an output file that can be supplied to '--set-file'. It will distribute the
given bandwidth (bw) values uniformly over the links between the given machines.

If you want to clear any set bandwidth throttles, you can send a reset request to a machine:
```bash
python shape_traffic_client.py --reset <ip1>:<ip2>:...
```
