#!/bin/sh
# Install dep
apt-get install debhelper dkms git -y
# Clone repo
cd /usr/local/src
git clone https://github.com/abbbi/nullfsvfs.git
cd nullfsvfs
# Build
git checkout v0.14
dpkg-buildpackage -us -uc
# Install
apt-get install ../nullfsvfs_0.14_armhf.deb -y
echo nullfs > /etc/modules-load.d/nullfs.conf
# Load
modprobe nullfs
echo "none	/srv/nullfs	nullfs	auto	0	0" >> /etc/fstab
# Mount
mkdir /srv/nullfs
mount /srv/nullfs
