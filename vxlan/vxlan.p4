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
