#!/usr/bin/env bash

# Echo commands as they are executed
set -x

# Variables
VM_NAME='fedora-base'
VB_DIR="${HOME}/vbox-vms"
VM_DIR="${VB_DIR}/${VM_NAME}"
SSH_PORT=30023

# Attempt cleanup
VBoxManage controlvm "${VM_NAME}" poweroff
VBoxManage unregistervm "${VM_NAME}" --delete
rm -rf "${VM_DIR}"

# From now on, exit on errors
set -e

# Download Fedora in VirtualBox format from LinuxVmImages
# https://www.linuxvmimages.com/images/fedora-35/
if [[ ! -f 'Fedora_36_VB.7z' ]]; then
  wget 'https://netix.dl.sourceforge.net/project/linuxvmimages/VirtualBox/F/Fedora/Fedora_36_VB.7z'
fi
mkdir -p "${VM_DIR}"
7z x 'Fedora_36_VB.7z' -o"${VM_DIR}" -y

# Create VM and rename
VBoxManage registervm "${VM_DIR}/Fedora_36_VB_LinuxVMImages.COM.vbox"
VBoxManage modifyvm "Fedora_36_VB_LinuxVMImages.COM" --name "${VM_NAME}"

# Basic VM settings:
VBoxManage modifyvm "${VM_NAME}" \
  --cpus 2 \
  --memory 8192 \
  --acpi on \
  --audio none \
  --vrde off

# The first network card is attached to VirtualBox's NAT with port forwarding for SSH.
# The second network card is attached to the internal network `ipanet`
VBoxManage modifyvm "${VM_NAME}" \
  --nic1 'nat' --natpf1 "ssh,tcp,localhost,${SSH_PORT},,22" \
  --nic2 'intnet' --intnet2 'ipanet'

# Start the VM and wait a bit
VBoxManage startvm "${VM_NAME}" --type headless
sleep 10

# Setup SSH key
sshpass -p 'fedora' ssh-copy-id \
  -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' \
  -p "${SSH_PORT}" -i freeipa_rsa fedora@localhost

# Provision
scp -F ssh_config -r 03-fedora-base/* fedora-base:/home/fedora
ssh -F ssh_config fedora-base sudo /home/fedora/provision.sh

# Take a snapshot that can be used to set up other Fedora machines.
# Make sure the snapshot is taken with the machine completely off
VBoxManage controlvm "${VM_NAME}" acpipowerbutton
sleep 10
VBoxManage snapshot "${VM_NAME}" take 'clone-me'
VBoxManage snapshot "${VM_NAME}" list
