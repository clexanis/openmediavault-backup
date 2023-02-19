#!/bin/bash
set -e

# Remove some service.
sudo systemctl disable --now rsyslog.service ModemManager.service wpa_supplicant.service apt-daily.timer apt-daily-upgrade.timer logrotate.timer

# Mark not wanted package as auto.
sudo apt-mark auto build-essential crda cryptsetup dphys-swapfile firmware-* gcc-* libcamera-apps-lite libcrypt1 libcryptsetup12 logrotate logsave manpages-dev mkvtoolnix ModemManager network-manager ntfs-3g p7zip-full pciutils pi-bluetooth python3-gpiozero python3-picamera2 python3-rpi.gpio raspberrypi-net-mods rsyslog tasksel tasksel-data triggerhappy v4l-utils wireless-tools wpasupplicant

# Set systemd-journald to not write log files.
printf "Storage=volatile\n" >> /etc/systemd/journald.conf
systemctl restart systemd-journald.service

# Configure systemd-networkd.
printf "[Match]\nName=en*\n[Network]\nDHCP=yes\n" > /etc/systemd/network/20-wired.network
systemctl enable systemd-networkd.service

# Purge useless packages and upgrade the system.
apt autopurge
apt update
apt dist-upgrade -y

# Configure zram
apt install zram-tools
printf "PERCENT=50\n" >> /etc/default/zramswap

# Deactivate useless parameters in rpi firmware.
printf "dtparam=i2c_arm=off\ndtparam=i2s=off\ndtparam=spi=off\ndtparam=audio=off\ncamera_auto_detect=0\ndisplay_auto_detect=0\ngpu_mem=16\nenable_uart=0\n"

# Configure log as a tmpfs
echo "tpmfs   /var/log        tmpfs   rw,nodev,nosuid,size=10M        0       0" >> /etc/fstab

# Remove all log files.
rm -rf /var/log*

# Reboot system
reboot now & exit
