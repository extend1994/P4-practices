#!/bin/bash

CLI_PATH=../../bmv2/tools/runtime_CLI.py
SWITCH_PATH=../../bmv2/targets/simple_router/simple_router

if [ $# -lt 1 ]; then
  echo "Usage: . run.sh filename"
else
  # Remove generated json files before regernating it
  rm -f *.json
  echo.LightBlue "Compile $1.p4"
  p4c-bmv2 --json $1.json $1.p4
  echo.LightBlue "Resetting mininet environment..."
  sudo mn -c
  echo.LightBlue "Turn on mininet environment..."
  sudo python ../../bmv2/mininet/1sw_demo.py --behavioral-exe ../../bmv2/targets/simple_router/simple_router --json vxlan.json &
  sleep 1
  echo.LightBlue "Apply entry rules to switch"
  $CLI_PATH --json vxlan.json < commands.txt
  echo.LightBlue "Resetting all counters..."
  echo "counter_reset inner_udp_counter" | $CLI_PATH --json vxlan.json
  echo "counter_reset inner_tcp_counter" | $CLI_PATH --json vxlan.json
  echo "counter_reset inner_icmp_counter" | $CLI_PATH --json vxlan.json
  echo "Reset done!"
  fg
fi
