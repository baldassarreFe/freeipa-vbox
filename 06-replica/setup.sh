#!/usr/bin/env bash

# Echo commands as they are executed
set -x

# Variables
VM_NAME='replica01'
VB_DIR="${HOME}/vbox-vms"
VM_DIR="${VB_DIR}/${VM_NAME}"
SSH_PORT=40201
VM_MAC='0800cccccccc'

# Attempt cleanup
VBoxManage controlvm "${VM_NAME}" poweroff
VBoxManage unregistervm "${VM_NAME}" --delete
rm -rf "${VM_DIR}"

# From now on, exit on errors
set -e

# Clone fedora VM
VBoxManage clonevm 'fedora-base' \
  --basefolder "${VB_DIR}" \
  --name "${VM_NAME}" \
  --snapshot 'clone-me' \
  --register

# Change port forwarding for SSH
VBoxManage modifyvm "${VM_NAME}" --natpf1 delete 'ssh'
VBoxManage modifyvm "${VM_NAME}" --natpf1 "ssh,tcp,localhost,${SSH_PORT},,22"

# Only needed to access FreeIPA from the outside, disabled for now:
# VBoxManage modifyvm "${VM_NAME} \
#   --natpf2 "http,tcp,,80,,80" \
#   --natpf2 "https,tcp,,443,,443" \
#   --natpf2 "ldap,tcp,,389,,389" \
#   --natpf2 "ldaps,tcp,,636,,636" \
#   --natpf2 "kerberos1,tcp,,88,,88" \
#   --natpf2 "kerberos2,tcp,,464,,464" \
#   --natpf2 "kerberos3,udp,,88,,88" \
#   --natpf2 "kerberos4,udp,,464,,464"

# Change MAC for internal network to get 192.168.56.201 from the DHCP
# Note: sometimes it says "Error: The machine is not mutable (state is Saved)",
# this happens if the original snapshot was taken with the VM running.
VBoxManage modifyvm "${VM_NAME}" --macaddress2 "${VM_MAC}"

# Start the VM and wait a bit
VBoxManage startvm "${VM_NAME}" --type headless
sleep 10

# Provision
scp -F ssh_config -r 06-replica/* replica01:/home/fedora
ssh -F ssh_config replica01 sudo /home/fedora/provision.sh

# Shutdown, snapshot, power up
VBoxManage controlvm "${VM_NAME}" acpipowerbutton
sleep 10
VBoxManage snapshot "${VM_NAME}" take 'pre-install'
VBoxManage snapshot "${VM_NAME}" list
sleep 10
VBoxManage startvm "${VM_NAME}" --type headless
