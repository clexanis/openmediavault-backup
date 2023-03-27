#!/bin/bash
set -e
cd /usr/local/src
# Use the latest version of zlib who support ARM crc32 instructions.
wget http://raspbian.raspberrypi.org/raspbian/pool/main/z/zlib/zlib1g_1.2.13.dfsg-1_armhf.deb
wget http://raspbian.raspberrypi.org/raspbian/pool/main/z/zlib/zlib1g-dev_1.2.13.dfsg-1_armhf.deb
apt install ./zlib1g_1.2.13.dfsg-1_armfh.deb ./zlib1g-dev_1.2.13.dfsg-1_armhf.deb -y
# Also use the latest version, which who will be compiled with the new zlib libraries.
git clone https://github.com/madler/pigz.git
cd pigz
git checkout v2.7
make
exit 0