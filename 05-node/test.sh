#!/usr/bin/env bash

# Exit on errors, echo commands as they are executed
set -e
set -x

# Get a kerberos ticket (pwd: qwerty123)
kinit admin
klist
# Default principal: admin@IPA.TEST
# Valid starting       Expires              Service principal
# 08/21/2022 15:20:30  08/22/2022 14:56:28  krbtgt/IPA.TEST@IPA.TEST

# Does the FreeIPA DNS know about this node?
ipa dnsrecord-find 'ipa.test' 'node01'
# node01 A 192.168.56.101
ipa host-find node01.ipa.test
# Host name: node01.ipa.test
# Platform: x86_64
# Operating system: 5.10.0-17-amd64
# Principal name: host/node01.ipa.test@IPA.TEST

# Does this node know about FreeIPA users?
id userone
# uid=988800003(userone) gid=988800003(userone) groups=988800003(userone)
