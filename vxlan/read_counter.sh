CLI_PATH=../../bmv2/tools/runtime_CLI.py

echo.LightYellow "Reading all counters"

echoPacketInfo(){
	echo -n "There is/are Inner "
	pkt_size=0
	if [[ $2 -gt 0 ]]; then
		pkt_size=$(( $3-50*$2 ))
		echo -ne "\033[92m$2\033[m"
	else
		echo -ne "\033[91m0\033[m"
	fi
	echo -n " $1 packet(s) with "
	if [[ $pkt_size -gt 0 ]]; then
		echo -ne "\033[92m$pkt_size\033[m"
	else
		echo -ne "\033[91m0\033[m"
	fi
	echo " bytes."
}

udp_info=$(echo "counter_read inner_udp_counter 0" | $CLI_PATH --json vxlan.json | grep -Eo "=[0-9]+")
udp_pkts=$(echo -n $udp_info | awk '{print $1}' | grep -Eo "[0-9]+")
udp_bytes=$(echo -n $udp_info | awk '{print $2}' | grep -Eo "[0-9]+")
echoPacketInfo UDP $udp_pkts $udp_bytes

tcp_info=$(echo "counter_read inner_tcp_counter 0" | $CLI_PATH --json vxlan.json | grep -Eo "=[0-9]+")
tcp_pkts=$(echo -n $tcp_info | awk '{print $1}' | grep -Eo "[0-9]+")
tcp_bytes=$(echo -n $tcp_info | awk '{print $2}' | grep -Eo "[0-9]+")
echoPacketInfo TCP $tcp_pkts $tcp_bytes

icmp_info=$(echo "counter_read inner_icmp_counter 0" | $CLI_PATH --json vxlan.json | grep -Eo "=[0-9]+")
icmp_pkts=$(echo -n $icmp_info | awk '{print $1}' | grep -Eo "[0-9]+")
icmp_bytes=$(echo -n $icmp_info | awk '{print $2}' | grep -Eo "[0-9]+")
echoPacketInfo ICMP $icmp_pkts $icmp_bytes
