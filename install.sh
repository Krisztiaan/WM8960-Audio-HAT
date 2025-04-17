#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 1>&2
   exit 1
fi

is_Raspberry=$(cat /proc/device-tree/model | awk  '{print $1}')
if [ "x${is_Raspberry}" != "xRaspberry" ] ; then
  echo "Sorry, this driver only works on raspberry pi"
  exit 1
fi

apt update
apt-get -y install i2c-tools libasound2-plugins
apt-get -y install alsa-utils

# install dtbos
cp wm8960-soundcard.dtbo /boot/overlays

#set kernel moduels
grep -q "i2c-dev" /etc/modules || \
  echo "i2c-dev" >> /etc/modules
grep -q "snd-soc-wm8960" /etc/modules || \
  echo "snd-soc-wm8960" >> /etc/modules
grep -q "snd-soc-wm8960-soundcard" /etc/modules || \
  echo "snd-soc-wm8960-soundcard" >> /etc/modules

#set dtoverlays
CONFIG_FILE=""
if [ -f "/boot/firmware/config.txt" ]; then
  CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f "/boot/config.txt" ]; then
  CONFIG_FILE="/boot/config.txt"
else
  echo "Error: Neither /boot/firmware/config.txt nor /boot/config.txt found." >&2
  exit 1 # Exit with an error code if no config file is found
fi

echo "Using configuration file: $CONFIG_FILE"
sudo sed -i -e 's:^#\s*dtparam=i2c_arm=on:dtparam=i2c_arm=on:g' "$CONFIG_FILE" || true

grep -qxF "dtoverlay=i2s-mmap" "$CONFIG_FILE" || \
  echo "dtoverlay=i2s-mmap" | sudo tee -a "$CONFIG_FILE" > /dev/null
grep -qxF "dtparam=i2s=on" "$CONFIG_FILE" || \
  echo "dtparam=i2s=on" | sudo tee -a "$CONFIG_FILE" > /dev/null
grep -qxF "dtoverlay=wm8960-soundcard" "$CONFIG_FILE" || \
  echo "dtoverlay=wm8960-soundcard" | sudo tee -a "$CONFIG_FILE" > /dev/null

#install config files
mkdir /etc/wm8960-soundcard || true
cp *.conf /etc/wm8960-soundcard
cp *.state /etc/wm8960-soundcard

#set service
cp wm8960-soundcard /usr/bin/
cp wm8960-soundcard.service /lib/systemd/system/
systemctl enable  wm8960-soundcard.service
systemctl start wm8960-soundcard

echo "------------------------------------------------------"
echo "Please reboot your raspberry pi to apply all settings"
echo "Enjoy!"
echo "------------------------------------------------------"
