#!/usr/bin/env bash

# Simulate P4 software switch
git clone https://github.com/p4lang/behavioral-model.git bmv2
# p4c-bm generates the JSON configuration for the behavioral-model (bmv2)
git clone https://github.com/p4lang/p4c-bm.git p4c-bmv2
git clone https://github.com/p4lang/tutorials.git
sudo apt-get install python-pip -y
sudo apt-get install mininet -y
sudo pip install scapy thrift networkx

cd bmv2
./install_deps.sh
./autogen.sh
./configure
make

cd ../p4c-bmv2
sudo pip install -r requirements.txt
# For compiling P4 v1.1 programs
# sudo pip install -r requirements_v1_1.txt
sudo python setup.py install

# p4c for p4_16
sudo apt-get install g++ git automake libtool libgc-dev bison flex libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev libboost-graph-dev pkg-config python python-scapy python-ipaddr tcpdump cmake -y
git clone --recursive https://github.com/p4lang/p4c.git
cd p4c
mkdir build
cd build
cmake ..
make -j4
make -j4 check
sudo make install # Enables commands to the global scale
