#!/bin/bash
DEFAULT_BANDWIDTH="1000mbit"
IF="eth0"

# Reset to initial state.
if [ $1 == "reset" ]; then
	echo "resetting bandwidth limits";

	# Delete the root queueing discipline (if it exists) to reset the system 
	# to normal.
	EXISTING_QDISC=$(tc qdisc show dev $IF | grep "default 10" | wc -l)
	if [ $EXISTING_QDISC != "0" ]; then
		tc qdisc delete dev $IF root
		tc qdisc delete dev $IF ingress	
	fi

# Restrict bandwidth from and to a certain IP address.
elif [ $1 == "set" ]; then

	# Add the root queueing discipline if it does not exist yet.
	EXISTING_QDISC=$(tc qdisc show dev $IF | grep "default 30" | wc -l)
	if [ $EXISTING_QDISC == "0" ]; then
		echo "initializing";

		# Create the root queueing discipline.
		tc qdisc add dev $IF root handle 1: htb default 30

		# Create the main class which will contain all other classes. We do
		# this, because that allows HTB to divide excess bandwidth amongst
		# all child classes.
		tc class add dev $IF parent 1: classid 1:1 htb rate $DEFAULT_BANDWIDTH

		# Create the default class for traffic that does not need to be shaped.
		tc class add dev $IF parent 1:1 classid 1:30 htb rate $DEFAULT_BANDWIDTH
	fi

	IP=$2
	BANDWIDTH=$3
	echo "restricting traffic with destination and source $IP to $BANDWIDTH";

	# We need a class for the bandwidth value and two filters for uploading and
	# downloading. In order to have distinct IDs for the classes, we use the
	# given IP address. We add up the 4 different parts of the IP address to come
	# up with an ID.
	CLASS_ID=0
	IFS=. ARR=(${IP##*-})
	for i in {0..3} ; do
		CLASS_ID=$(($CLASS_ID+${ARR[i]}))
	done
	unset IFS

	# Update the class if it's already there and add it otherwise
	EXISTING_CLASSES=$(tc class show dev $IF | grep "1:$CLASS_ID" | wc -l)
	if [ $EXISTING_CLASSES != "0" ]; then
		tc class change dev $IF parent 1:1 classid 1:$CLASS_ID htb rate $BANDWIDTH
	else
		tc class add dev $IF parent 1:1 classid 1:$CLASS_ID htb rate $BANDWIDTH
	fi	

	# Only add the filter if it is not already there.
	EXISTING_FILTERS=$(tc filter show dev $IF | grep "flowid 1:$CLASS_ID" | wc -l)
	if [ $EXISTING_FILTERS == "0" ]; then
		tc filter add dev $IF parent 1: protocol ip prio 1 u32 match ip dst $IP flowid 1:$CLASS_ID
		tc filter add dev $IF parent 1: protocol ip prio 1 u32 match ip src $IP flowid 1:$CLASS_ID
	fi

# Restrict all traffic on the default interface.
elif [ $1 == "set-all" ]; then
	BANDWIDTH=$2

	# Delete any set rules first.
	EXISTING_QDISC=$(tc qdisc show dev $IF | grep "default 10" | wc -l)
	if [ $EXISTING_QDISC != "0" ]; then
		echo "deleting default rules";
		tc qdisc del dev eth0 root
		tc qdisc del dev eth0 ingress
	fi

	# Police the incoming traffic, drop packets over the bandwidth rate.
	tc qdisc add dev eth0 handle ffff: ingress
	tc filter add dev eth0 parent ffff: protocol ip prio 10 u32 match u32 0 0 action police rate $BANDWIDTH burst 5000k drop

	# Create the root queueing discipline for egress traffic.
	tc qdisc add dev $IF root handle 1: htb default 10

	# Create the main class.
	tc class add dev $IF parent 1: classid 1:1 htb rate $BANDWIDTH

	# Create the parent class.
	tc class add dev $IF parent 1:1 classid 1:10 htb rate $BANDWIDTH

	# Log the bandwidth value for others to use.
	BANDWIDTH_VALUE="${BANDWIDTH/mbit/}"
	echo "$BANDWIDTH_VALUE" > /var/log/current_bandwidth
fi

