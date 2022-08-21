#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Hostname
hostnamectl set-hostname 'node01.ipa.test'
sed -i 's/debian-base/node01 node01.ipa.test/' /etc/hosts

# Internal network interface with DHCP
install -o root -g root -m 644 etc/network/interfaces.d/enp0s8 /etc/network/interfaces.d/enp0s8
ifdown enp0s8
ifup   enp0s8

# System DNS config
# TODO upon restart, resolv.conf is overwritten and whichever interface comes
#      up first (enp0s3, enp0s8) sets the DNS address and search domain. In
#      some cases this breaks DNS queries for *.test
install -o root -g root -m 644 etc/resolv.conf /etc/resolv.conf

# Packages
# Note: when installed with apt, kerberos would interactively ask the user
#       for some default values. We skip the questions since ipa-client-install
#       will take care of setting the right values in /etc/krb5.conf
echo '
deb http://deb.debian.org/debian bullseye-backports main contrib
deb-src http://deb.debian.org/debian bullseye-backports main contrib
' >> /etc/apt/sources.list
apt update
DEBIAN_FRONTEND=noninteractive apt install -y freeipa-client

# TODO firewall, drop all incoming except SSH

# FreeIPA client install
ipa-client-install \
  --mkhomedir \
  --realm 'IPA.TEST' \
  --domain 'ipa.test' \
  --server 'server.ipa.test' \
  --hostname 'node01.ipa.test' \
  --principal 'admin' \
  --password 'qwerty123' \
  --ntp-pool 'pool.ntp.org' \
  --enable-dns-updates \
  --unattended
