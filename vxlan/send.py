#!/usr/bin/python
from scapy.all import *

def main():
  # Assign mac and ip address according the topology bmv2/mininet/1sw_demo.py built
  h1_mac = "00:04:00:00:00:00"
  h2_mac = "00:04:00:00:00:01"
  h1_ip  = "10.0.0.10"
  h2_ip  = "10.0.1.10"
  load_contrib('vxlan') # enable vxlan use in scapy package
  pkt = Ether(dst=h2_mac, src=h1_mac)/IP(dst=h2_ip, src=h1_ip)/UDP()/VXLAN(vni=61)/Raw(load="\x00\x01\x00\x02\x01")
  pkt.show() # show the packet info before senting the packet
  sendp(pkt, iface = "eth0")

if __name__ == '__main__':
  main()
