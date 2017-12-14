#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: . run.sh filename"
else
  # Remove generated json files before regernating it
  rm -f *.json
  p4c-bmv2 --json $1.json $1.p4
  sudo python ../../bmv2/mininet/1sw_demo.py --behavioral-exe ../../bmv2/targets/simple_router/simple_router --json $1.json &
  sleep 1
  ../../bmv2/tools/runtime_CLI.py --json $1.json --thrift-port 9090 < commands.txt
  echo "Ready!"
  fg
fi
