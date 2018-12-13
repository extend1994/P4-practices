#!/usr/bin/env bash

set -e

# Useful parameters
P4PATH=~/p4-repos
COMMON_PATH=~/p4-repos/common
NUM_CORES=$(grep -c ^processor /proc/cpuinfo)
SYSTEM_BASE=$(grep "ID_LIKE" /etc/os-release | awk -F'=' '{print $2}')

echo "Checking your OS..."
if [ ${OSTYPE} != "linux-gnu" ] || [ ${SYSTEM_BASE} != "debian" ]; then
  echo "Can't apply this script in your OS"
  exit 1
else
  echo "Continue to set your P4 environment :)"
fi

mkdir -p ${P4PATH} && cd ${P4PATH}

echo "Install p4_14 or p4_16? [14/16(Default)]"
read p4Version

echo "Installing required packages/tools via apt and pip..."
sudo apt-get install python-pip -y
sudo apt-get install mininet -y
sudo pip install scapy thrift networkx

if [ -z $p4Version ]; then
  p4Version="16"
else

  echo "Install P4 vim syntax..."
  curl -o- -L http://bit.ly/2LjrOgh | bash

  mkdir -p ${COMMON_PATH} && cd ${COMMON_PATH}
  if [ -e "protobuf" ]; then
    echo "protobuf repo has existed!"
  else
    echo "Cloning protobuf repository..."
    git clone https://github.com/google/protobuf.git
  fi

  echo "Installing protobuf dependencies..."
  sudo apt-get install autoconf curl unzip -y
  echo "Building and installing protobuf..."
  cd protobuf
  git checkout tags/v3.2.0
  git submodule update --init --recursive
  ./autogen.sh
  ./configure --prefix=/usr
  make -j${NUM_CORES}
  sudo make install
  sudo ldconfig
  cd python
  sudo python setup.py install

  cd ${COMMON_PATH}
  if [ -e "grpc" ]; then
    echo "grpc repo has existed!"
  else
    echo "Cloning grpc repository..."
    git clone https://github.com/grpc/grpc.git
  fi

  cd grpc
  git checkout tags/v1.3.2
  git submodule update --init --recursive
  make -j${NUM_CORES}
  sudo make install
  sudo ldconfig
  sudo pip install grpcio

  cd ${COMMON_PATH}
  if [ -e "PI" ]; then
    echo "PI repo for P4Runtime has existed!"
  else
    echo "Cloning PI repository for P4Runtime..."
    git clone --recursive git clone https://github.com/p4lang/PI.git
  fi

  # Simulate P4 software switch
  if [ -e "bmv2" ]; then
    echo "behavioral model has existed!"
  else
    echo "Cloning behavioral model repository..."
    git clone https://github.com/p4lang/behavioral-model.git bmv2
  fi

  cd PI
  ./autogen.sh
  ./configure --with-proto
  make -j${NUM_CORES}
  sudo make install
  sudo ldconfig

  # Simulate P4 software switch
  if [ -e "bmv2" ]; then
    echo "behavioral model has existed!"
  else
    echo "Cloning behavioral model repository..."
    git clone https://github.com/p4lang/behavioral-model.git bmv2
  fi

  echo "Building and installing the behavioral model..."
  cd bmv2
  ./install_deps.sh --enable-debugger --with-pi
  ./autogen.sh
  ./configure
  make -j${NUM_CORES}
  sudo make install
  # Simple_switch_grpc target
  cd targets/simple_switch_grpc
  ./autogen.sh
  ./configure --with-thrift
  make -j${NUM_CORES}
  sudo make install
  sudo ldconfig

  cd ${COMMON_PATH}
  if [ -e "tutorials" ]; then
    echo "tutorials repo has existed!"
  else
    echo "Cloning tutorials repository..."
    git clone https://github.com/p4lang/tutorials.git
  fi

  if [ ${p4Version} == "14" ]; then

    mkdir -p ${P4PATH}"/14" && cd ${P4PATH}"/14"
    # p4c-bm generates the JSON configuration for the behavioral-model (bmv2)
    if [ -e "p4c-bmv2" ]; then
      echo "p4c-bmv2 repo has existed!"
    else
      echo "Cloning p4c-bmv2 repository..."
      git clone https://github.com/p4lang/p4c-bm.git p4c-bmv2
    fi

    echo "Installing p4c-bmv2..."
    cd p4c-bmv2
    sudo pip install -r requirements.txt
    sudo python setup.py install

  else

    mkdir -p ${P4PATH}"/16" && cd ${P4PATH}"/16"
    if [ -e "p4c" ]; then
      echo "p4c repo has existed!"
    else
      echo "Cloning p4c repository..."
      git clone --recursive https://github.com/p4lang/p4c.git
    fi

    echo "Installing p4c dependencies..."
    sudo apt-get install g++ git automake libtool libgc-dev bison flex libfl-dev \
                        libgmp-dev libboost-dev libboost-iostreams-dev libboost-graph-dev \
                        pkg-config python python-scapy python-ipaddr tcpdump cmake \
                        doxygen graphviz texlive-full -y
    echo "Building and installing p4c..."
    cd p4c
    mkdir build && cd build
    cmake ..
    make -j${NUM_CORES}
    make -j${NUM_CORES} check
    sudo make install # Enables commands to the global scale
    sudo ldconfig
  fi # end of p4Version check
fi

echo "Environments are all set!!"
