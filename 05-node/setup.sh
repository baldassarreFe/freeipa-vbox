#!/usr/bin/env bash

# Echo commands as they are executed
set -x

# Variables
VM_NAME='node01'
VB_DIR="${HOME}/vbox-vms"
VM_DIR="${VB_DIR}/${VM_NAME}"
SSH_PORT=40001

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

# Start the VM and wait a bit
VBoxManage startvm "${VM_NAME}" --type headless
sleep 10

# Provision
scp -F ssh_config -r 05-node/* node01:/home/debian
ssh -F ssh_config node01 sudo /home/debian/provision.sh

# Shutdown, snapshot, power up
VBoxManage controlvm "${VM_NAME}" acpipowerbutton
sleep 10
VBoxManage snapshot "${VM_NAME}" take 'provisioned'
VBoxManage snapshot "${VM_NAME}" list
VBoxManage startvm "${VM_NAME}" --type headless
sleep 10

# Run some tests
ssh -F ssh_config node01 /home/debian/test.sh
