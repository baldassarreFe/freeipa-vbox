#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Hostname
hostnamectl set-hostname 'ns1.test'
sed -i 's/debian-base/ns1 ns1.test/' /etc/hosts

# Packages
apt-get update
apt-get upgrade -y
apt-get install -y bind9 bind9utils bind9-doc

# TODO firewall, drop all incoming except SSH and DNS

# Internal network interface with DHCP
install -o root -g root -m 644 etc/network/interfaces.d/enp0s8 /etc/network/interfaces.d/enp0s8
ifdown enp0s8
ifup   enp0s8

# Expected output when bringing up enp0s8:
# DHCPDISCOVER on enp0s8 to 255.255.255.255 port 67 interval 8
# DHCPOFFER of 192.168.56.253 from 192.168.56.250
# DHCPREQUEST for 192.168.56.253 on enp0s8 to 255.255.255.255 port 67
# DHCPACK of 192.168.56.253 from 192.168.56.250

# BIND config
install -o root -g bind -m 644 etc/bind/named.conf.local   /etc/bind/named.conf.local
install -o root -g bind -m 644 etc/bind/named.conf.options /etc/bind/named.conf.options
install -o root -g bind -m 775 -d /var/log/named
install -o root -g bind -m 755 -d /etc/bind/zones
install -o root -g bind -m 644 etc/bind/zones/db.test                    /etc/bind/zones/db.test
install -o root -g bind -m 644 etc/bind/zones/db.56.168.192.in-addr.arpa /etc/bind/zones/db.56.168.192.in-addr.arpa

# Check config and start BIND
named-compilezone -o - -i local test /etc/bind/zones/db.test
systemctl restart named

# System DNS config
# TODO upon restart, resolv.conf is overwritten and whichever interface comes
#      up first (enp0s3, enp0s8) sets the DNS address and search domain. In
#      some cases this breaks DNS queries for *.test
install -o root -g root -m 644 etc/resolv.conf /etc/resolv.conf

# Tests DNS queries (expected outputs)
dig +short ns1.test # 192.168.56.253
ping -c 3  ns1.test # 192.168.56.253
ping -c 3  ns1      # 192.168.56.253
dig ipa.test SOA    # no answer
