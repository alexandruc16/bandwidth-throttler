#! /usr/bin/python
import sys
from time import sleep
from datetime import datetime

def process_net_file(content, interface):
    res = ""
    for line in content.split('\n'):
        if interface in line:
            res = line
            break
    res = ' '.join(res.split())
    data_list = res.split(' ')
    incoming = data_list[1]
    outgoing = data_list[9]
    return int(incoming), int(outgoing)

def get_crnt_net_data(interface):
    content = ""
    with open("/proc/net/dev", "r") as net_file:
        content = net_file.read()
    return process_net_file(content, interface)

def main(interface, outgoing_file, incoming_file):
    out_file = open(outgoing_file, "w")
    in_file = open(incoming_file, "w")
    old_in, old_out = get_crnt_net_data(interface)
    while 1:
        sleep(1)

        new_in, new_out = get_crnt_net_data(interface)
        diff_in = new_in - old_in
        diff_out = new_out - old_out

        old_in = new_in
        old_out = new_out

        out_file.write(str((diff_out / (float)(1000 * 1000)) * 8) + "\n")
        out_file.flush()

        in_file.write(str((diff_in / (float)(1000 * 1000)) * 8) + "\n")
        in_file.flush()

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("usage: monitor_bw.py INTERFACE OUTGOING_FILE INCOMING_FILE\n")
    else:
        interface = sys.argv[1]
        outgoing_file = sys.argv[2]
        incoming_file = sys.argv[3]
        main(interface, outgoing_file, incoming_file)

