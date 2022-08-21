#!/usr/bin/env bash

# Exit on errors, echo commands as they are executed
set -e
set -x

# Who is in charge of the subzone ipa.test?
dig +short ipa.test SOA
# ipa.test. 86400 IN SOA server.ipa.test. hostmaster.ipa.test. 1661084192 3600 900 1209600 3600

# Get a kerberos ticket (pwd: qwerty123)
kinit admin
klist
# Default principal: admin@IPA.TEST
# Valid starting       Expires              Service principal
# 08/21/2022 10:17:22  08/22/2022 09:42:03  krbtgt/IPA.TEST@IPA.TEST

# What DNS servers are in use within FreeIPA?
ipa dnsconfig-show
# IPA DNS servers: server.ipa.test
ipa dnsserver-find
# Server name: server.ipa.test
# SOA mname override: server.ipa.test.
# Forwarders: 192.168.56.253
# Forward policy: only

# What DNS zones are managed by FreeIPA?
ipa dnszone-find
# Zone name: ipa.test.
# Active zone: TRUE
# Authoritative nameserver: server.ipa.test.
# Administrator e-mail address: hostmaster.ipa.test.
# SOA serial: 1648817955
# SOA refresh: 3600
# SOA retry: 900
# SOA expire: 1209600
# SOA minimum: 3600
# BIND update policy: grant IPA.TEST krb5-self * A; grant IPA.TEST krb5-self * AAAA; grant IPA.TEST krb5-self * SSHFP;
# Dynamic update: TRUE
# Allow query: any;
# Allow transfer: none;

# What are the DNS records for the ipa.test subzone?
# TODO why does the IP of enp0s3 appear in the ipa-ca record?
ipa dnsrecord-find 'ipa.test'
# @      NS server.ipa.test.
# ipa-ca A  10.0.2.15, 192.168.56.200
# server A  192.168.56.200
# ...

# What CA are known to FreeIPA?
ipa ca-find
# Name: ipa
# Description: IPA CA
# Authority ID: 8a1f5505-ef3c-4d74-ab9f-9d971ea72497
# Subject DN: CN=Certificate Authority,O=IPA.TEST
# Issuer DN: CN=Certificate Authority,O=IPA.TEST

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

# What machines are FreeIPA servers?
ipa hostgroup-show ipaservers
# Description: IPA server hosts
# Member hosts: server.ipa.test
ipa server-show server.ipa.test
# Managed suffixes: domain, ca
# Enabled server roles: CA server, DNS server, IPA master

# What services are run by FreeIPA?
ipa service-find | grep 'Principal name'
# Principal name: DNS/server.ipa.test@IPA.TEST
# Principal name: HTTP/server.ipa.test@IPA.TEST
# Principal name: dogtag/server.ipa.test@IPA.TEST
# Principal name: ipa-dnskeysyncd/server.ipa.test@IPA.TEST
# Principal name: ldap/server.ipa.test@IPA.TEST

# Add a user
ipa user-add 'userone' --first='User' --last='One' --random
# User login: userone
# First name: User
# Last name: One
# Full name: User One
# Display name: User One
# Initials: UO
# Home directory: /home/userone
# GECOS: User One
# Login shell: /bin/sh
# Principal name: userone@IPA.TEST
# Principal alias: userone@IPA.TEST
# User password expiration: 20220821144001Z
# Email address: userone@ipa.test
# Random password: ...
# UID: 988800003
# GID: 988800003
# Password: True
# Member of groups: ipausers
# Kerberos keys available: True
id userone
# uid=988800003(userone) gid=988800003(userone) groups=988800003(userone)
ipa user-find 'userone'
# User login: userone
# First name: User
# Last name: One
# Home directory: /home/userone
# Login shell: /bin/sh
# Principal name: userone@IPA.TEST
# Principal alias: userone@IPA.TEST
# Email address: userone@ipa.test
# UID: 988800003
# GID: 988800003
# Account disabled: False
