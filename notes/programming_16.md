# P4_16 Programming

## Table of Content

- [Header](#header)
- [Parser](#parser)
- [Table](#table)
- [Action](#action)
- [Control](#control)
- [Others](#others)

## Header

### Types

#### Basics

- *bit\<n>*: Unsigned integer of length n, bit == bit\<1>
- *int\<n>*: Signed integer of length n >= 2
- *varbit\<n>*: variable length bitstring

#### Derived

- *header*
  - Byte-aligned
  - valid/invalid
  - Can contain basic types
- *struct*: array of headers
- *typedef*: alia of another type

### Example

```p4
typedef bit<48> mac_addr_t;

header ethernet_t {
  bit<48> dstAddr;
  //or mac_addr_t dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

header vlan_tag_t {
  bit<3> pri;
  bit<1> cfi;
  bit<12> vid;
  bit<16> etherType;
}

struct my_headers_t {
  ethernet_t ethernet;
  vlan_tag_t[2] vlan_tag;
}

header ipv4_options_t {
  varbit<320> options;
}
```

## Parser

### Parsing

### Deparsing

See more details on page 97 of v1 spec.

```p4
  // Expressed as another control function - normal one
  control MyDeparser(packet_out packet,
                             in my_headers_t hdr)
  {
    apply {
      /* Layer 2 */
      packet.emit(hdr.ethernet);
      packet.emit(hdr.vlan_tag);

      /* Layer 2.5 */
      packet.emit(hdr.mpls);

      /* Layer 3 */
      packet.emit(hdr.arp);
      packet.emit(hdr.arp_ipv4);
      packet.emit(hdr.ipv4);
      packet.emit(hdr.ipv6);

      /* Layer 4 */
      packet.emit(hdr.icmp);
      packet.emit(hdr.tcp);
      packet.emit(hdr.udp);
    }
  }

  // Simplified Deparsing
  struct my_headers_t {
    ethernet_t     ethernet;
    vlan_tag_t [2] vlan_tag;
    mpls_t     [5] mpls;
    arp_t          arp;
    arp_ipv4_t     arp_ipv4;
    ipv4_t         ipv4;
    ipv6_t         ipv6;
    icmp_t         icmp;
    tcp_t          tcp;
    udp_t          udp;
  }

  control MyDeparser(packet_out packet,
                in my_headers_t hdr)
  {
    apply {
      packet.emit(hdr); // Headers will be deparsed in struct order
    }
  }
```



### Example

```p4
parser MyParser(packet_in               packet
                out   my_headers_t      hdr
                inout my_metadata_t     meta
                inout standard_metada_t standard_metadata)
{
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100 &&& 0xEFFF : parse_vlan_tag;
      0x0800 : parse_ipv4;
      0x86DD : parse_ipv6;
      0x0806 : parse_arp;
      default : accept;
    }
  }

  state parse_vlan_tag {
    packet.extract(hdr.vlan_tag.next);
    transition select(hdr.vlan_tag.last.etherType) {
      0x8100 : parse_vlan_tag;
      0x0800 : parse_ipv4;
      0x86DD : parse_ipv6;
      0x0806 : parse_arp;
      default : accept;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    transition select(hdr.ipv4.ihl) {
      0 .. 4: reject;
      5: accept;
      default: parse_ipv4_options;
    }
  }

  state parse_ipv4_options {
    packet.extract(hdr.ipv4.options,
                   (hdr.ipv4.ihl - 5) << 2);
    transition accept;
  }

  state parse_ipv6 {
    packet.extract(hdr.ipv6);
    transition accept;
  }
}
```

## Table

定義

- 要 match 的東西及 match 的方式
- 可能要執行的 actions
- 額外的屬性
  - size
  - 預設 action
  - entries
- 每個 table 會有一或多個 entries，每個 entry 包含
  - A specific key to match on
  - A single action
  - (Optional) action data

## Action

可以使用 `if`！

### Actions Galore: Operating on Headers

- Header Validity bit manipulation

  ```p4
  header.setValid();   // add_header
  header.setInvalid(); // remove_header
  header.isValid();
  ```

- Header Assignment

  ```p4
  header = { f1, f2, ..., fn }
  header1 = header2
  ```

- Special operations on Header Stacks

  - In the parsers
    - `header_stack.next`
    - `header_stack.last`
    - `header_stack.lastIndex`
  - In the controls
    - `header_stack[i]`
    - `header_stack.size`
    - `header_stack.push_front(int count)`
    - `header_stack.pop_front(int count)`

### Actions Galore: Bit Manipulation

- Bit-string concatenation

  ```p4
  action set_ipmcv4_mac_da_1() {
    hdr.ethernet.dstAddr = 24w0x01005E ++ 1w0 ++ hdr.ipv4.dstAddr[22:0];
  }
  ```

- Bit-slicing - `header.field[msb:lsb]`

  ```p4
  action set_ipmcv4_mac_da_2() {
    hdr.ethernet.dstAddr[47:24] = 0x01005E;
    hdr.ethernet.dstAddr[23:23] = 0;;
    hdr.ethernet.dstAddr[22:0] = hdr.ipv4.dstAddr[22:0];
  }
  ```

## Control

### Standard Arithmetic and Logical operations

- +, -, *
- ~, &, |, ^, >>, <<
- ==, !=, >, >=, <, <=
- **No division/modulo**

## Table, action & control full example

```p4
const bit<9> DROP_PORT = 511; /* Specific to V1 architecture */

action mark_to_drop() { /* Already defined in v1model.p4 */
  standard_metadata.egress_spec = DROP_PORT;
  standard_metadata.mgast_grp = 0;
}

action l3_switch(bit<9> port,
                 bit<48> new_mac_da,
                 bit<48> new_mac_sa,
                 bit<12> new_vlan)
{
  /* Forward the packet to the specified port */
  standard_metadata.metadata.egress_spec = port
  /* L2 Modifications */
  hdr.ethernet.dstAddr = new_mac_da;
  hdr.ethernet.srcAddr = mac_sa;
  hdr.vlan_tag[0].vlanid = new_vlan;

  /* IP header modification (TTL decrement) */
  hdr.ipv4.ttl = hdr.ipv4.ttl – 1;
}

table ipv4_host {
  key = {
    meta.ingress_metadata.vrf: exact;
    hdr.ipv4.dstAddr         : exact;
  }
  actions = {
    l3_switch;
    noAction;
  }
  default_action = noAction(); // Defined in core.p4
  size = 65536;
}

control MyIngress(
  inout my_headers_t        hdr,
  inout my_metadata_t       meta,
  inout standard_metadata_t standard_metadata
{
  /* Local Declarations */
  action swap_mac(inout bit<48> dst, inout bit<48> src) {
    bit<48> tmp;
    tmp = dst;
    dst = src;
    src = tmp;
  }

  action reflect_to_other_port() {
    standard_metadata.egress_spec = standard_metadata.ingress_port ^ 1;
  }
  
  table assign_vrf {...}
  table ipv4_host {...}

  bit<48> tmp;
  apply {
    /* Can also do assignment directly */
    if (hdr.ethernet.dstAddr[40:40] == 0x1) {
      mark_to_drop();
    } else {
      swap_mac(hdr.ethernet.dstAddr, hdr.ethernet.srcAddr);
      reflect_to_other_port();
    }
  }
  
  apply {
    assign_vrf.apply();
    if (hdr.ipv4.isValid()) {
      ipv4_host.apply();
    }
  }
  
  apply {
     /**********************************************
       Switch() statement
       - Only used for the results of match-action
       - Each case should be a block statement
       - Default case is optional

       Exit and Return Statements
       - return – go to the end of the current control
       - exit – go to the end of the top-level control
       - Useful to skip further processing
     **********************************************/
     switch (ipv4_lpm.apply().action_run) {
       l3_switch_nexthop: { nexthop.apply(); }
          l3_switch_ecmp: { ecmp.apply(); }
                 l3_drop: { exit; } //
                 default: { /* Not needed. Do nothing */ }
     }
   }
}
```

## Others

### Declaring and Initializing Variables

```p4
bit<16> ecmp_group; //P4_16 has Typecast!
bit<8> another_var = 5;

const bit<16> ETHERTYPE_IPV4 = 0x0800; //Better than #define!
const bit<16> ETHERTYPE_IPV6 = 0x86DD;

ethernet_t eth;
vlan_tag_t vtag = { 3w2, 0, 12w13, 16w0x8847 }; //Safe constants with explicit widths
```





