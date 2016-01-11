#! /usr/bin/python
import sys
from time import sleep
from datetime import datetime
import psutil


def process_net_file(content, interface, proc_index):
	"""
	Processes the /proc/net/dev file.
	"""
	res = ""
	for line in content.split('\n'):
		if interface in line:
			res = line
			break
	res = ' '.join(res.split())
	data_list = res.split(' ')
	incoming = data_list[1]
	outgoing = data_list[proc_index]
	return int(incoming), int(outgoing)


def get_crnt_net_data(interface, proc_index):
	"""
	Uses /proc/net/dev to get the number of bytes sent and received.
	"""
	content = ""
	with open("/proc/net/dev", "r") as net_file:
		content = net_file.read()
	return process_net_file(content, interface, proc_index)


def get_crnt_psutil_data(interface):
	"""
	Uses psutil to extract the number of bytes sent and received.
	"""
	current_stats = psutil.net_io_counters(pernic=True)
	interface_stats = current_stats[interface]
	return int(interface_stats.bytes_recv), int(interface_stats.bytes_sent)


def main(interface, outgoing_file, incoming_file, method, proc_index):
	out_file = open(outgoing_file, "w")
	in_file = open(incoming_file, "w")
	if method == 'proc':
		old_in, old_out = get_crnt_net_data(interface, proc_index)
	else:
		old_in, old_out = get_crnt_psutil_data(interface)
	while 1:
		sleep(1)
		if method == 'proc':
			new_in, new_out = get_crnt_net_data(interface, proc_index)
		else:
			new_in, new_out = get_crnt_psutil_data(interface)
		diff_in = new_in - old_in
		diff_out = new_out - old_out

		old_in = new_in
		old_out = new_out

		out_file.write(str((diff_out / (float)(1000 * 1000)) * 8) + "\n")
		out_file.flush()

		in_file.write(str((diff_in / (float)(1000 * 1000)) * 8) + "\n")
		in_file.flush()


if __name__ == "__main__":
	if len(sys.argv) < 5:
		print("usage: monitor_bw.py INTERFACE OUTGOING_FILE INCOMING_FILE METHOD [PROC_INDEX]\n")
	else:
		interface = sys.argv[1]
		outgoing_file = sys.argv[2]
		incoming_file = sys.argv[3]
		method = sys.argv[4]
		if len(sys.argv) == 6:
			proc_index = int(sys.argv[5])
		else:
			proc_index = 9
		main(interface, outgoing_file, incoming_file, method, proc_index)
