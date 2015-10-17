#!/bin/bash
DEFAULT_BANDWIDTH="1000mbit"
IF="eth0"

# Reset to initial state.
if [ $1 == "reset" ]; then
	echo "resetting bandwidth limits";

	# Delete the root queueing discipline (if it exists) to reset the system 
	# to normal.
	EXISTING_QDISC=$(tc qdisc show dev $IF | grep "default 30" | wc -l)
	if [ $EXISTING_QDISC != "0" ]; then
		tc qdisc delete dev $IF root	
	fi

# Initialize.
elif [ $1 == "initialize" ]; then
	echo "initializing";

	# Create the root queueing discipline.
	tc qdisc add dev $IF root handle 1: htb default 30

	# Create the main class which will contain all other classes. We do
	# this, because that allows HTB to divide excess bandwidth amongst
	# all child classes.
	tc class add dev $IF parent 1: classid 1:1 htb rate $DEFAULT_BANDWIDTH

	# Create the default class for traffic that does not need to be shaped.
	tc class add dev $IF parent 1:1 classid 1:30 htb rate $DEFAULT_BANDWIDTH

# Restrict bandwidth from and to a certain IP address.
elif [ $1 == "set" ]; then
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
fi
