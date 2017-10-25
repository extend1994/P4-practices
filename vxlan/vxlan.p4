// Define header type
header_type ethernet_t {
  fields {
    dstAddr: 48;
    srcAddr: 48;
    etherType: 16;
  }
}

header_type ipv4_t {
  fields {
    version : 4;
    ihl : 4;
    diffserv : 8;
    totalLen : 16;
    identification : 16;
    flags : 3;
    fragOffset : 13;
    ttl : 8;
    protocol : 8;
    hdrChecksum : 16;
    srcAddr : 32;
    dstAddr: 32;
  }
}

header_type udp_t {
  fields {
    srcPort: 16;
    dstPort: 16;
    len: 16;
    checksum: 16;
  }
}

header_type vxlan_t {
  fields {
    flags: 8;
    reserved: 24;
    vni: 24;
    reserved2: 8;
  }
}

header_type inner_header_t {
  fields{
    src: 16;
    dst: 16;
    ctr: 8;
  }
}

// Create header instances for parser
header ethernet_t ethernet_header;
header ipv4_t ipv4_header;
header udp_t udp_header;
header vxlan_t vxlan_header;
header inner_header_t inner_header;

#define ETHERTYPE_IPV4 0x0800
#define UDP_PROC 0x11
#define VXLAN_UDP_PORT 4789
#define XLAN_PACKET 0x08

parser start {
  return parse_ethernet;
}

parser parse_ethernet {
  extract(ethernet_header);
  return select(latest.etherType) {
    ETHERTYPE_IPV4 : parse_ipv4;
    default: ingress;
  }
}

parser parse_ipv4 {
  extract(ipv4_header);
  return select(latest.protocol) {
    UDP_PROC: parse_udp;
    default: ingress;
  }
}

parser parse_udp {
  extract(udp_header);
  return select(latest.dstPort){
    VXLAN_UDP_PORT: parse_vxlan;
    default: ingress;
  }
}

parser parse_vxlan {
  extract(vxlan_header);
  return select(latest.flags) {
    XLAN_PACKET: parse_inner_header;
    default: ingress;
  }
}

parser parse_inner_header {
  extract(inner_header);
  return ingress;
}

action add_vxlan_counter(out_port) {
  modify_field(standard_metadata.egress_spec, out_port);
  add_to_field(inner_header.ctr, 1);
}

action dropPkt() {
  drop();
}

table vxlan_counter_table {
  reads {
    vxlan_header.vni: exact;
  }
  actions {
    add_vxlan_counter;
  }
}

table dropPkt_table {
  actions {
    dropPkt;
  }
}

// Define control flows
control ingress {
  if(valid(vxlan_header)){
    apply(vxlan_counter_table);
  } else {
    apply(dropPkt_table);
  }
}

control egress {
  //It's fine to keep empty
}
