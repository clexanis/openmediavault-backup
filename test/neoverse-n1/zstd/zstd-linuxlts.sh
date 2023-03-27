#!/bin/bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.14.tar.xz
xz -d linux-6.1.14.tar.xz
rm linux-6.1.14.tar.xz
for i in {1..15}; do zstdmt -b$i linux-6.1.14.tar; done
