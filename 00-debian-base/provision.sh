#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Install updates
apt update
apt upgrade -y

# Disable welcome message
echo '' > /etc/motd

# Hostname
hostnamectl set-hostname 'debian-base'
sed -i 's/debian11.linuxvmimages.local/debian-base/' /etc/hosts
sed -i 's/debian11//' /etc/hosts

# TODO firewall, drop all incoming except SSH
