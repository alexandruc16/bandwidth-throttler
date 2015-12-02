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
	EXISTING_QDISC=$(tc qdisc show dev $IF | grep "ingress" | wc -l)
	if [ $EXISTING_QDISC != "0" ]; then
		echo "deleting default rules";
		tc qdisc del dev eth0 root
		tc qdisc del dev eth0 ingress
		tc qdisc del dev ifb0 root
	fi

	# See if the virtual interface for ingress traffic already exists.
	EXISTING_VIRTUAL_IF=$(ifconfig | grep "ifb0")
	if [ -z "$EXISTING_VIRTUAL_IF" ]; then
		# Create the virtual interface.
		modprobe ifb numifbs=1
		
		# Set it up.
		ip link set dev ifb0 up

	fi	
	tc qdisc add dev eth0 handle ffff: ingress
	tc filter add dev eth0 parent ffff: protocol ip prio 10 u32 match u32 0 0 action mirred egress redirect dev ifb0

	# Create the root queueing disciplines for ingress and egress traffic.
	tc qdisc add dev $IF root handle 1: htb default 10
	tc qdisc add dev ifb0 root handle 1: htb default 10

	# Create the main classes.
	tc class add dev $IF parent 1: classid 1:1 htb rate $DEFAULT_BANDWIDTH
	tc class add dev ifb0 parent 1: classid 1:1 htb rate $BANDWIDTH

	# Create the parent class for all traffic both ingress and egress.
	tc class add dev $IF parent 1:1 classid 1:10 htb rate $DEFAULT_BANDWIDTH
	tc class add dev ifb0 parent 1:1 classid 1:10 htb rate $BANDWIDTH

	# Create the sub classes for ingress and egress traffic from the default interface.
	# This appears to be working better than letting the parent class deal with
	# all the traffic.
	CHILD_BANDWIDTH=${BANDWIDTH%mbit}
	CHILD_BANDWIDTH=$((CHILD_BANDWIDTH/2))

	# Adding 20 percent more bandwidth to ingress traffic seems to balance things out.	
	IMBALANCE=`echo "(1/5)*$CHILD_BANDWIDTH" | bc -l`
	IMBALANCE=${IMBALANCE%.*}
	SPECIFIER=mbit
	INGRESS_BANDWIDTH=$((CHILD_BANDWIDTH+IMBALANCE))
	INGRESS_BANDWIDTH=$INGRESS_BANDWIDTH$SPECIFIER
	EGRESS_BANDWIDTH=$((CHILD_BANDWIDTH-IMBALANCE))
	EGRESS_BANDWIDTH=$EGRESS_BANDWIDTH$SPECIFIER
	tc class add dev ifb0 parent 1:10 classid 1:20 htb rate $INGRESS_BANDWIDTH ceil $BANDWIDTH
	tc filter add dev ifb0 parent 1: protocol ip u32 match ip dst 10.141.0.139 flowid 1:20
	tc class add dev ifb0 parent 1:10 classid 1:30 htb rate $EGRESS_BANDWIDTH ceil $BANDWIDTH
	tc filter add dev ifb0 parent 1: protocol ip u32 match ip src 10.141.0.139 flowid 1:30

	# Redirect egress traffic to the virtual interface.
	tc filter add dev eth0 parent 1: protocol ip prio 20 u32 match u32 0 0 action mirred egress redirect dev ifb0
fi

