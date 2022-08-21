# FreeIPA in VirtualBox

## VirtualBox setup

### Installation
Add this line to `/etc/apt/sources.list`:
```
deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian bionic contrib
```

Install virtualbox and the extension pack:
```bash
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -

sudo apt update
sudo apt install -y sshpass gcc make linux-headers-$(uname -r) dkms virtualbox-6.1

wget https://download.virtualbox.org/virtualbox/6.1.34/Oracle_VM_VirtualBox_Extension_Pack-6.1.34.vbox-extpack
sudo VBoxManage extpack install Oracle_VM_VirtualBox_Extension_Pack-6.1.34.vbox-extpack
VBoxManage list extpacks
```

Guides:
- https://websiteforstudents.com/virtualbox-5-2-on-ubuntu-16-04-lts-server-headless/
- https://www.virtualbox.org/wiki/Linux_Downloads
- https://www.virtualbox.org/manual/ch07.html#vboxheadless

### Storage

All VMs are placed in the same folder:
```bash
mkdir -p "${HOME}/vbox-vms"
```

### Remote access

Each VM has a port forwarding rul to expose its port 22 to the host.
Create an SSH key that will be installed on all machines.
```bash
ssh-keygen -N '' -f 'freeipa_rsa'
```

### Networking

All VMs access the internet through the default NAT network in VirtualBox.

All VMs also have access to an internal network called `ipanet`,
which is created automatically when it's referenced by the first VM.

VirtualBox has an
[internal DHCP](https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/vboxmanage-dhcpserver.html)
but it does not work well in our tests.
Sometimes a VM that was given a static address gets a random one.
For this reason, we have a simple DHCP server in its own VM that
manages the internal network `192.168.56.0/24`.

### Useful commands:

Listings and info:
```bash
VBoxManage list vms
VBoxManage list runningvms
VBoxManage list intnets
VBoxManage list hdds
VBoxManage showvminfo "${VM_NAME}"
```

Cleanup:
```bash
VBoxManage controlvm "${VM_NAME}" acpipowerbutton # or poweroff
VBoxManage unregistervm "${VM_NAME}" --delete

for VM_NAME in debian-base dhcp dns fedora-base server replica01 node01; do
    VBoxManage controlvm    "${VM_NAME}" poweroff
    VBoxManage unregistervm "${VM_NAME}" --delete
    rm -rf "${HOME}/vbox-vms/${VM_NAME}"
done
```

VBoxManage [documentation](https://www.virtualbox.org/manual/ch08.html).

### Virtual machines overview

| VM name       | Note                                            | MAC                 | IP               |                  DNS | SSH   |
| ------------- | ----------------------------------------------- | :------------------ | :--------------- | -------------------: | ----- |
| `debian-base` | Bare Debian                                     | -                   | -                |                      | 30022 |
| `dhcp`        | DHCP server                                     | -                   | `192.168.56.250` |                      | 40200 |
| `dns`         | DNS server for the `.test` zone                 | `08:00:AA:AA:AA:AA` | `192.168.56.253` |           `ns1.test` | 40253 |
| `fedora-base` | Fedora just before FreeIPA server/replica       | -                   | -                |                    - | 30023 |
| `server`      | FreeIPA server and DNS for the `.ipa.test` zone | `08:00:BB:BB:BB:BB` | `192.168.56.200` |    `server.ipa.test` | 40200 |
| `node01`      | A client                                        | -                   | -                |    `node01.ipa.test` | 40001 |
| `replica01`   | FreeIPA replica                                 | `08:00:CC:CC:CC:CC` | `192.168.56.201` | `replica01.ipa.test` | 40201 |

## Debian base VM

Download a ready-made Debian VM, customize it a bit and do all updates.
All other Debian-based VMs will be cloned from this.
The default user and password are `debian:debian`.

```bash
00-debian-base/setup.sh
```

## DHCP

The DHCP server is a clone of the debian VM, the provisioning script
sets up a DHCP server that manages the `192.168.56.0/24` range on the
`enp0s8` interface and pushes the options relative to DNS configuration.
```bash
01-dhcp/setup.sh
```

DHCP logs can be inspected with:
```bash
ssh -F ssh_config dhcp sudo cat /var/log/syslog | grep DHCP
```

Ranges:
- The range `100-199` is for generic clients whose address
  does not matter, including compute nodes
- The range `200-249` can be used for static reservations for certain servers
- DHCP server at `250`
- DNS server at `253`

## DNS

The DNS server is a clone of the debian VM, the provisioning script sets up a
DNS server for the `.test` zone. The DNS server performs recursion to the
`.ipa.test` subzone where the DNS records for FreeIPA are managed.
```bash
02-dns/setup.sh
```

All DNS logs and queries can be inspected with:
```bash
ssh -F ssh_config dns sudo cat /var/log/named/default.log
ssh -F ssh_config dns sudo cat /var/log/named/queries.log
```

Guides:
- https://wiki.debian.org/Bind9
- https://help.ubuntu.com/community/BIND9ServerHowto
- https://ubuntu.com/server/docs/service-domain-name-service-dns
- https://www.digitalocean.com/community/tutorials/how-to-configure-bind-as-a-private-network-dns-server-on-ubuntu-18-04


## Fedora base VM

Download a ready-made Fedora VM, customize it a bit and do all updates.
All other Fedora-based VMs, namely the FreeIPA server and replicas,
will be cloned from this. The default user and password are `fedora:fedora`.
```bash
03-fedora-base/setup.sh
```

Firewall docs:
- [firewall-cmd tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-8)
- [firewall-cmd and nmcli](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/sec-working_with_zones)

## FreeIPA Server

Starting from the Fedora base image, install the FreeIPA server with
a self-signed internal CA and a DNS server.

```bash
04-server/setup.sh
```

The DNS server is authoritative for the `ipa.test` subzone and will forward
other queries to the configured upstream resolver
[(documentation)](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/managing-dns-forwarding-in-idm_configuring-and-managing-idm).

Note: trying to set up the reverse zone with the
`--reverse-zone 56.168.192.in-addr.arpa.` option
gives this error:
```
Checking DNS domain 56.168.192.in-addr.arpa., please wait ...
DNS zone 56.168.192.in-addr.arpa. already exists in DNS and is handled by server(s): localhost.
```
This is a long-standing [bug](https://pagure.io/freeipa/issue/8700)
between FreeIPA and systemd-resolve which tries to resolve the reverse
address of the server even if it shouldn't. For now I'm using `--no-reverse`
and hoping that it doesn't break replication.

Output snippets from the installer:
```
This program will set up the IPA Server.
Version 4.9.10

This includes:
  * Configure a stand-alone CA (dogtag) for certificate management
  * Configure the NTP client (chronyd)
  * Create and configure an instance of Directory Server
  * Create and configure a Kerberos Key Distribution Center (KDC)
  * Configure Apache (httpd)
  * Configure DNS (bind)
  * Configure SID generation
  * Configure the KDC to enable PKINIT

...

The IPA Master Server will be configured with:
Hostname:       server.ipa.test
IP address(es): 192.168.56.200
Domain name:    ipa.test
Realm name:     IPA.TEST

The CA will be configured with:
Subject DN:   CN=Certificate Authority,O=IPA.TEST
Subject base: O=IPA.TEST
Chaining:     self-signed

BIND DNS server will be configured to serve IPA domain with:
Forwarders:       192.168.56.253
Forward policy:   only
Reverse zone(s):  No reverse zone

NTP pool:       pool.ntp.org
...

Setup complete

Next steps:
	1. You must make sure these network ports are open:
		TCP Ports:
		  * 80, 443: HTTP/HTTPS
		  * 389, 636: LDAP/LDAPS
		  * 88, 464: kerberos
		  * 53: bind
		UDP Ports:
		  * 88, 464: kerberos
		  * 53: bind
		  * 123: ntp

	2. You can now obtain a kerberos ticket using the command: 'kinit admin'
	   This ticket will allow you to use the IPA tools (e.g., ipa user-add)
	   and the web user interface.

Be sure to back up the CA certificates stored in /root/cacert.p12
These files are required to create replicas. The password for these
files is the Directory Manager password
The ipa-server-install command was successful
```

FreeIPA install logs can be inspected with:
```bash
ssh -F ssh_config server sudo less /var/log/ipaserver-install.log
```

After the installation and the snapshot, some tests are run.
Compare with the expected output in [04-server/test.sh](./04-server/test.sh).

## FreeIPA Client (compute node)

The first node is a clone of the debian VM, the provisioning script sets up
the interfaces and installs the FreeIPA client.
```bash
05-node/setup.sh
```

Output snippets from the installer:
```
This program will set up IPA client.
Version 4.9.8

WARNING: conflicting time&date synchronization service 'ntp' will be disabled in favor of chronyd

Client hostname: node01.ipa.test
Realm: IPA.TEST
DNS Domain: ipa.test
IPA Server: server.ipa.test
BaseDN: dc=ipa,dc=test
NTP pool: pool.ntp.org

Synchronizing time
Augeas failed to configure file /etc/chrony/chrony.conf
Using default chrony configuration.
Attempting to sync time with chronyc.
Time synchronization was successful.
Successfully retrieved CA cert
    Subject:     CN=Certificate Authority,O=IPA.TEST
    Issuer:      CN=Certificate Authority,O=IPA.TEST
    Valid From:  2022-08-21 20:03:43
    Valid Until: 2042-08-21 20:03:43

Enrolled in IPA realm IPA.TEST
Created /etc/ipa/default.conf
Configured /etc/sssd/sssd.conf
Configured /etc/krb5.conf for IPA realm IPA.TEST
Systemwide CA database updated.
Hostname (node01.ipa.test) does not have A/AAAA record.
Missing A/AAAA record(s) for host node01.ipa.test: 192.168.56.101.
Missing reverse record(s) for address(es): 192.168.56.101.
Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub
Adding SSH public key from /etc/ssh/ssh_host_ed25519_key.pub
Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub
SSSD enabled
Configured /etc/openldap/ldap.conf
Configured /etc/ssh/ssh_config
Configured /etc/ssh/sshd_config.d/04-ipa.conf
Configuring ipa.test as NIS domain.
Client configuration complete.
The ipa-client-install command was successful
```

After the installation and the snapshot, some tests are run.
Compare with the expected output in [05-node/test.sh](./05-node/test.sh).

## FreeIPA CA and DNS replica

Starting from the Fedora base image, install the FreeIPA replica with
both DNS and CA replication.

```bash
06-replica/setup.sh
```

Output snippets from the installer
(TODO there are some warnings about DNS records):
```
This program will set up IPA client.                                                                                                                                                                                                          
Version 4.9.10                                                                                                                                                                                                                                
                                                                                                                                                                                                                                              
Discovery was successful!                                                                                                                                                                                                                     
Client hostname: replica01.ipa.test                                                                                                                                                                                                           
Realm: IPA.TEST                                                                                                                                                                                                                               
DNS Domain: ipa.test                                                                                                                                                                                                                          
IPA Server: server.ipa.test                                                                                                                                                                                                                   
BaseDN: dc=ipa,dc=test                                                                                                                                                                                                                        
NTP pool: pool.ntp.org                                                                                                                                                                                                                        
                                                                                                                                                                                                                                              
Synchronizing time                                                                                                                                                                                                                            
Configuration of chrony was changed by installer.                                                                                                                                                                                             
Attempting to sync time with chronyc.                                                                                                                                                                                                         
Time synchronization was successful.                                                                                                                                                                                                          
Successfully retrieved CA cert                                                                                                                                                                                                                
    Subject:     CN=Certificate Authority,O=IPA.TEST                                                                                                                                                                                          
    Issuer:      CN=Certificate Authority,O=IPA.TEST                                                                                                                                                                                          
    Valid From:  2022-08-21 20:03:43                                                                                                                                                                                                          
    Valid Until: 2042-08-21 20:03:43                                                                                                                                                                                                          
                                                                                                                                                                                                                                              
Enrolled in IPA realm IPA.TEST                                                                                                                                                                                                                
Created /etc/ipa/default.conf                                                                                                                                                                                                                 
Configured /etc/sssd/sssd.conf                                                                                                                                                                                                                
Configured /etc/krb5.conf for IPA realm IPA.TEST                                                                                                                                                                                              
Systemwide CA database updated.                                                                                                                                                                                                               
Extra A/AAAA record(s) for host replica01.ipa.test: 10.0.2.15, fe80::c638:cbf:af2a:f2fb, fe80::2fac:a5f1:cc77:ee9d.                                                                                                                           
Incorrect reverse record(s):                                                                                                                                                                                                                  
192.168.56.201 is pointing to replica01. instead of replica01.ipa.test.                                                                                                                                                                       
192.168.56.201 is pointing to replica01.local. instead of replica01.ipa.test.                                                                                                                                                                 
Adding SSH public key from /etc/ssh/ssh_host_ecdsa_key.pub                                                                                                                                                                                    
Adding SSH public key from /etc/ssh/ssh_host_ed25519_key.pub                                                                                                                                                                                  
Adding SSH public key from /etc/ssh/ssh_host_rsa_key.pub                                                                                                                                                                                      
SSSD enabled                                                                                                                                                                                                                                  
Configured /etc/openldap/ldap.conf                                                                                                                                                                                                            
Configured /etc/ssh/ssh_config                                                                                                                                                                                                                
Configured /etc/ssh/sshd_config.d/04-ipa.conf                                                                                                                                                                                                 
Configuring ipa.test as NIS domain.                                                                                                                                                                                                           
Client configuration complete.                                                                                                                                                                                                                
The ipa-client-install command was successful

Unable to resolve the IP address 192.168.56.200 to a host name, check /etc/hosts and DNS name resolution                                                                                                                                      
Lookup failed: Preferred host replica01.ipa.test does not provide DNS.                                                                                                                                                                        
Reverse DNS resolution of address 192.168.56.200 (server.ipa.test) failed. Clients may not function properly. Please check your DNS setup. (Note that this check queries IPA DNS directly and ignores /etc/hosts.)                            
Invalid IP address fe80::2fac:a5f1:cc77:ee9d for replica01.ipa.test: cannot use link-local IP address fe80::2fac:a5f1:cc77:ee9d                                                                                                               
Invalid IP address fe80::c638:cbf:af2a:f2fb for replica01.ipa.test: cannot use link-local IP address fe80::c638:cbf:af2a:f2fb                                                                                                                 
Run connection check to master                                                                                                                                                                                                                
Connection check OK

...

Global DNS configuration in LDAP server is empty
You can use 'dnsconfig-mod' command to set global DNS options that
would override settings in local named.conf files

...

The ipa-replica-install command was successful
```

FreeIPA replica logs can be inspected with:
```bash
ssh -F ssh_config replica01 sudo less /var/log/ipareplica-install.log
```

After the installation and the snapshot, some tests are run.
Compare with the expected output in [06-replica/test.sh](./06-replica/test.sh).

Guides:
- [Replica docs](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/linux_domain_identity_authentication_and_policy_guide/creating-the-replica)

## Final tests

Test that replication works as intended:
1. Turn off `server` and wait for node01 to take notice
2. Create a new user from `node01`
3. Check that `replica01` knows about the user
4. Turn on `server` and wait for FreeIPA to start and sync
5. Check that `server` also knows about the user (might have to wait a bit)

```bash
07-final-tests/test.sh
```

Note: in step 2, we call `kinit admin` on `node01` to get a Kerberos ticket.
For this to work while  `server` is down, `node01` must know about the
replication agreement and ask `replica01`. 
The replication agreement is written in the DNS records of FreeIPA,
then `node01` must also be able to resolve `replica01` by querying the
non-authoritative `dns` for its address. That's why there are 2 glue records
in the zone configuration on `dns`.

Note: in step 2, the replica might fail to create a user:
```
ipa: ERROR: Operations error: Allocation of a new value for range cn=posix ids,cn=distributed numeric assignment plugin,cn=plugins,cn=config failed! Unable to proceed.
```
This happens because the range of IDs that is used for new users is not
initialized on a replica upon creation, but after the first use during which
the primary server must be available [(reference)](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_identity_management/adjusting-id-ranges-manually_configuring-and-managing-idm). 
To make sure that a replica has a range of IDs to draw from, create a dummy
user when the replica is first installed and then check the IDs with:
`ipa-replica-manage dnarange-show`
