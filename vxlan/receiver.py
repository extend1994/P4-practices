#!/usr/bin/python
from scapy.all import *
from scapy.all import sniff
import sys
import struct

class colors:
  DEFAULT   = '\033[0m' # white
  BOLDER    = '\033[1m'
  UNDERLINE = '\033[4m'
  RED     = '\033[91m'
  GREEN   = '\033[92m'
  YELLOW  = '\033[93m'
  BLUE    = '\033[94m'
  PURPLE  = '\033[95m'

def handle_pkt(packet):
  print colors.YELLOW + "New packet!"
  print colors.DEFAULT
  load_contrib('vxlan') # enable vxlan use in scapy package
  try:
    packet[UDP].decode_payload_as(VXLAN) # change the way of raw data decoding
  except:
    print colors.RED
    print "Unexpected"

def main():
  sniff(filter="dst 10.0.1.10", iface = "eth0", prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
  main()
