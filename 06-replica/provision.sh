#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Hostname
hostnamectl set-hostname 'replica01.ipa.test'

# Checks before installation (expected output)
hostname --fqdn                             # replica01.ipa.test
ip -4 addr show enp0s8                      # 192.168.56.201
dig +short 201.56.168.192.in-addr.arpa. PTR # replica01.ipa.test. replica01.
dig ipa.test SOA                            # ipa.test. 86400 IN SOA server.ipa.test. hostmaster.ipa.test. 1661084192 3600 900 1209600 3600
nmcli                                       # 192.168.56.253 is the DNS for 'test'

# FreeIPA replica install with CA and DNS replication
ipa-replica-install \
  --realm 'IPA.TEST' \
  --domain 'ipa.test' \
  --hostname 'replica01.ipa.test' \
  --ip-address '192.168.56.201' \
  --principal 'admin' \
  --admin-password 'qwerty123' \
  --mkhomedir \
  --ntp-pool 'pool.ntp.org' \
  --setup-ca \
  --setup-dns \
  --forwarder '192.168.56.253' \
  --forward-policy 'only' \
  --no-reverse \
  --no-dnssec-validation \
  --unattended
