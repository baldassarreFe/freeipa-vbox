#!/usr/bin/env bash

# Echo commands as they are executed
set -x

# Variables
VM_NAME='dns'
VB_DIR="${HOME}/vbox-vms"
VM_DIR="${VB_DIR}/${VM_NAME}"
SSH_PORT=40253
VM_MAC='0800aaaaaaaa'

# Attempt cleanup
VBoxManage controlvm "${VM_NAME}" poweroff
VBoxManage unregistervm "${VM_NAME}" --delete
rm -rf "${VM_DIR}"

# From now on, exit on errors
set -e

# Clone debian VM
VBoxManage clonevm 'debian-base' \
  --basefolder "${VB_DIR}" \
  --name "${VM_NAME}" \
  --snapshot 'clone-me' \
  --register

# Change port forwarding for SSH
VBoxManage modifyvm "${VM_NAME}" --natpf1 delete 'ssh'
VBoxManage modifyvm "${VM_NAME}" --natpf1 "ssh,tcp,localhost,${SSH_PORT},,22"

# Change MAC for internal network to get 192.168.56.253 from the DHCP
# Note: sometimes it says "Error: The machine is not mutable (state is Saved)",
# this happens if the original snapshot was taken with the VM running.
VBoxManage modifyvm "${VM_NAME}" --macaddress2 "${VM_MAC}"

# Start the VM and wait a bit
VBoxManage startvm "${VM_NAME}" --type headless
sleep 10

# Provision
scp -F ssh_config -r 02-dns/* dns:/home/debian
ssh -F ssh_config dns sudo /home/debian/provision.sh

# Shutdown, snapshot, power up
VBoxManage controlvm "${VM_NAME}" acpipowerbutton
sleep 10
VBoxManage snapshot "${VM_NAME}" take 'provisioned'
VBoxManage snapshot "${VM_NAME}" list
sleep 10
VBoxManage startvm "${VM_NAME}" --type headless
