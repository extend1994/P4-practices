#!/usr/bin/python
from scapy.all import *

class colors:
  DEFAULT   = '\033[0m' # white
  BOLDER    = '\033[1m'
  UNDERLINE = '\033[4m'
  RED     = '\033[91m'
  GREEN   = '\033[92m'
  YELLOW  = '\033[93m'
  BLUE    = '\033[94m'
  PURPLE  = '\033[95m'

def main():
  # Assign mac and ip address according the topology bmv2/mininet/1sw_demo.py built
  h1_mac    = "00:04:00:00:00:00"
  h2_mac    = "00:04:00:00:00:01"
  in_h1_mac = "00:04:00:00:00:02"
  in_h2_mac = "00:04:00:00:00:03"
  h1_ip     = "10.0.0.10"
  h2_ip     = "10.0.1.10"
  in_h1_ip  = "10.0.2.10"
  in_h2_ip  = "10.0.3.10"
  load_contrib('vxlan') # enable vxlan use in scapy package
  pkt = Ether(dst=h2_mac,src=h1_mac)/IP(dst=h2_ip,src=h1_ip)/UDP()/VXLAN(vni=61)/\
        Ether(dst=in_h2_mac, src=in_h1_mac)/IP(dst=in_h2_ip,src=in_h1_ip)/UDP()/\
        Raw(load="\x00\x01\x00\x02\x01")
  print colors.YELLOW
  print "Send a VXLAN(VNI=61) packet with " + str(len(pkt[VXLAN][Ether])) + " bytes inner UDP frame"
  print colors.DEFAULT
  sendp(pkt, iface = "eth0")

  pkt = Ether(dst=h2_mac,src=h1_mac)/IP(dst=h2_ip,src=h1_ip)/UDP()/VXLAN(vni=60)/\
        Ether(dst=in_h2_mac, src=in_h1_mac)/IP(dst=in_h2_ip,src=in_h1_ip)/TCP()/\
        Raw(load="\x00\x01\x00\x02\x01")
  print colors.YELLOW
  print "Send a VXLAN(VNI=60) packet with " + str(len(pkt[VXLAN][Ether])) + " bytes inner TCP frame"
  print colors.DEFAULT
  sendp(pkt, iface = "eth0")

  pkt = Ether(dst=h2_mac,src=h1_mac)/IP(dst=h2_ip,src=h1_ip)/UDP()/VXLAN(vni=61)/\
        Ether(dst=in_h2_mac, src=in_h1_mac)/IP(dst=in_h2_ip,src=in_h1_ip)/ICMP()/\
        Raw(load="\x00\x01\x00\x02\x01")
  print colors.YELLOW
  print "Send a VXLAN(VNI=61) packet with " + str(len(pkt[VXLAN][Ether])) + " bytes inner ICMP frame"
  print colors.DEFAULT
  sendp(pkt, iface = "eth0")

if __name__ == '__main__':
  main()
