#!/usr/bin/python
from scapy.all import *
from scapy.all import sniff
import sys
import struct

def handle_pkt(packet):
  load_contrib('vxlan') # enable vxlan use in scapy package
  packet[UDP].decode_payload_as(VXLAN) # change the way of raw data decoding
  packet.show() # show the received packet info

def main():
  sniff(iface = "eth0", prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
  main()
