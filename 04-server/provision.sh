#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Hostname
hostnamectl set-hostname 'server.ipa.test'

# Checks before installation (expected output)
hostname --fqdn                             # server.ipa.test
ip -4 addr show enp0s8                      # 192.168.56.200
dig +short 200.56.168.192.in-addr.arpa. PTR # server.ipa.test. server.
dig ipa.test SOA                            # no answer
nmcli                                       # 192.168.56.253 is the DNS for 'test'

# FreeIPA server install with internal CA and DNS
ipa-server-install \
  --realm 'IPA.TEST' \
  --domain 'ipa.test' \
  --hostname 'server.ipa.test' \
  --ip-address '192.168.56.200' \
  --netbios-name 'IPASERVER' \
  --ds-password 'qwerty123' \
  --admin-password 'qwerty123' \
  --mkhomedir \
  --ntp-pool 'pool.ntp.org' \
  --setup-dns \
  --forwarder '192.168.56.253' \
  --forward-policy 'only' \
  --no-reverse \
  --no-dnssec-validation \
  --unattended

# TODO: instead of --no-reverse, the command should use
# --reverse-zone '56.168.192.in-addr.arpa.', so that a reverse zone
# is also created. However, the installer terminates with an error
# due to a bug in systemd-resolve https://pagure.io/freeipa/issue/8700
