#!/usr/bin/env bash

# Exit on errors, echo commands as they are executed
set -e
set -x

# Get a kerberos ticket (pwd: qwerty123)
kinit admin
klist
# Default principal: admin@IPA.TEST
# Valid starting       Expires              Service principal
# 08/21/2022 17:05:50  08/22/2022 16:40:58  krbtgt/IPA.TEST@IPA.TEST

# What DNS servers are in use within FreeIPA?
ipa dnsconfig-show
# IPA DNS servers: replica01.ipa.test, server.ipa.test
ipa dnsserver-find
# Server name: replica01.ipa.test
# Forwarders: 192.168.56.253
# Forward policy: only
# Server name: server.ipa.test
# Forwarders: 192.168.56.253
# Forward policy: only

# What are the DNS records for the ipa.test subzone?
ipa dnsrecord-find 'ipa.test'
# @         NS server.ipa.test., replica01.ipa.test.
# server    A  192.168.56.201
# replica01 A  192.168.56.201
# node01    A  192.168.56.101
# ...

# What certificates are managed by FreeIPA?
ipa cert-find | grep 'Subject'
# Subject: CN=Certificate Authority,O=IPA.TEST
# Subject: CN=OCSP Subsystem,O=IPA.TEST
# Subject: CN=server.ipa.test,O=IPA.TEST
# Subject: CN=CA Subsystem,O=IPA.TEST
# Subject: CN=CA Audit,O=IPA.TEST
# Subject: CN=ipa-ca-agent,O=IPA.TEST
# Subject: CN=IPA RA,O=IPA.TEST
# Subject: CN=server.ipa.test,O=IPA.TEST
# Subject: CN=server.ipa.test,O=IPA.TEST
# Subject: CN=server.ipa.test,O=IPA.TEST
# Subject: CN=replica01.ipa.test,O=IPA.TEST
# Subject: CN=replica01.ipa.test,O=IPA.TEST
# Subject: CN=replica01.ipa.test,O=IPA.TEST
# Subject: CN=replica01.ipa.test,O=IPA.TEST

# What machines are FreeIPA servers?
ipa hostgroup-show ipaservers
# Description: IPA server hosts
# Member hosts: server.ipa.test, replica01.ipa.test
ipa server-show replica01.ipa.test
# Managed suffixes: domain, ca
# Enabled server roles: CA server, DNS server, IPA master

# Does the toplogy include the new replica?
ipa topologysegment-find ca
# Segment name: replica01.ipa.test-to-server.ipa.test
# Left node: replica01.ipa.test
# Right node: server.ipa.test
# Connectivity: both
ipa topologysegment-find domain
# Segment name: replica01.ipa.test-to-server.ipa.test
# Left node: replica01.ipa.test
# Right node: server.ipa.test
# Connectivity: both

# What range of IDs will be used by each replica when creating users?
# Note that the range on each replica is not initialized upon creation
# but after the first use, e.g. creating a user. 
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/adjusting-id-ranges-manually_configuring-and-managing-idm
ipa-replica-manage dnarange-show
# server.ipa.test: 1256600004-1256799999
# replica01.ipa.test: No range set
ipa user-add 'usertwo' --first='User' --last='Two' --random
# User login: usertwo
ipa-replica-manage dnarange-show
# server.ipa.test: 1256600004-1256700499
# replica01.ipa.test: 1256700501-1256799999
