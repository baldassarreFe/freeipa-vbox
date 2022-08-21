#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Hostname
hostnamectl set-hostname 'dhcp.test'
sed -i 's/debian-base/dhcp dhcp.test/' /etc/hosts

# Packages (DHCP server will try to start after installation and fail)
apt update
apt upgrade -y
apt install -y isc-dhcp-server

# TODO firewall, drop all incoming except SSH and DHCP

# Internal network interface with static IP
install -o root -g root -m 644 etc/network/interfaces.d/enp0s8 /etc/network/interfaces.d/enp0s8
ifdown enp0s8
ifup   enp0s8

# DHCP
sed 's/INTERFACESv4=""/INTERFACESv4="enp0s8"/' -i /etc/default/isc-dhcp-server
install -o root -g root -m 644 etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
systemctl restart isc-dhcp-server.service
systemctl status  isc-dhcp-server.service
