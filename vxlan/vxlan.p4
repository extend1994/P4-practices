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

header_type tcp_t {
  fields {
    srcPort : 16;
    dstPort : 16;
    seqNo : 32;
    ackNo : 32;
    dataOffset : 4;
    res : 4;
    flags : 8;
    window : 16;
    checksum : 16;
    urgentPtr : 16;
  }
}

header_type icmp_t {
  fields {
    typeCode : 16;
    hdrChecksum : 16;
  }
}

header_type vxlan_t {
  fields {
    flags: 8;
    reserved: 24;
    vni: 24;
    qreserved2: 8;
  }
}

// Create header instances for parser
header ethernet_t ethernet_header;
header ipv4_t ipv4_header;
header udp_t udp_header;
header vxlan_t vxlan_header;
header ethernet_t inner_ethernet_header;
header ipv4_t inner_ipv4_header;
header udp_t inner_udp_header;
header tcp_t inner_tcp_header;
header icmp_t inner_icmp_header;

#define ETHERTYPE_IPV4 0x0800
#define UDP_PROC 0x11
#define TCP_PROC 0x06
#define ICMP_PROC 0x01
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
  extract(inner_ethernet_header);
  return select(latest.etherType) {
    ETHERTYPE_IPV4: parse_inner_ipv4;
    default: ingress;
  }
}

parser parse_inner_ipv4 {
  extract(inner_ipv4_header);
  return select(latest.protocol) {
    UDP_PROC: parse_inner_udp;
    TCP_PROC: parse_inner_tcp;
    ICMP_PROC:parse_inner_icmp;
    default: ingress;
  }
}

parser parse_inner_udp {
  extract(inner_udp_header);
  return parse_inner_header;
}

parser parse_inner_tcp {
  extract(inner_tcp_header);
  return parse_inner_header;
}

parser parse_inner_icmp {
  extract(inner_icmp_header);
  return parse_inner_header;
}

action correct_egress_port(out_port) {
  modify_field(standard_metadata.egress_spec, out_port);
}

action dropPkt() {
  drop();
}

action noop() {
}

counter inner_udp_counter {
  type: packets_and_bytes;
  direct: vxlan_verify_udp;
}

counter inner_tcp_counter {
  type: packets_and_bytes;
  direct: vxlan_verify_tcp;
}

counter inner_icmp_counter {
  type: packets_and_bytes;
  direct: vxlan_verify_icmp;
}

table vxlan_verify_udp {
  reads {
    vxlan_header.vni: exact;
    inner_udp_header: valid;
  }
  actions {
    correct_egress_port;
    noop;
  }
}

table vxlan_verify_tcp {
  reads {
    vxlan_header.vni: exact;
    inner_tcp_header: valid;
  }
  actions {
    correct_egress_port;
    noop;
  }
}

table vxlan_verify_icmp {
  reads {
    vxlan_header.vni: exact;
    inner_icmp_header: valid;
  }
  actions {
    correct_egress_port;
    noop;
  }
}

table dropPkt_table {
  actions {
    dropPkt;
  }
}

// Define control flows
control ingress {
  if (valid(vxlan_header)) {
    if (valid(inner_icmp_header)) {
      apply(vxlan_verify_icmp);
    }
    if(valid(inner_udp_header)){
      apply(vxlan_verify_udp);
    }
    if (valid(inner_tcp_header)) {
      apply(vxlan_verify_tcp);
    }
  } else {
    apply(dropPkt_table);
  }
}

control egress {
  //It's fine to keep empty
}
