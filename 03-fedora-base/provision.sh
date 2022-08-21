#!/usr/bin/env bash

# Must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Must run as root"
  exit 1
fi

# Echo commands as they are executed
set -x

# Disable IPv6 but keep it on loopback otherwise ipa-server-install complains
cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
sysctl --load

# Packages
dnf upgrade -y
dnf install -y firewalld bind-utils freeipa-server freeipa-server-dns

# Disable welcome message
echo '' > /etc/motd

# Hostname
hostnamectl set-hostname fedora-base

# Configure public firewall zone
systemctl enable --now firewalld
firewall-cmd --zone=public --add-service={ssh,freeipa-ldap,freeipa-ldaps,dns}
firewall-cmd --zone public --list-all
firewall-cmd --runtime-to-permanent

# Set zone for all interfaces (valid until reboot)
nmcli device modify 'enp0s3' connection.zone 'public'
nmcli device modify 'enp0s8' connection.zone 'public'
firewall-cmd --get-active-zones

# Set zone for all interfaces permanently
# Note: per-interface zones are possible by editing some config files
firewall-cmd --set-default-zone public

# Tests DNS queries (expected outputs)
dig +short ns1.test # 192.168.56.253
ping -c 3  ns1.test # 192.168.56.253
ping -c 3  ns1      # 192.168.56.253
dig ipa.test SOA    # no answer
