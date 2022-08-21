#!/usr/bin/env bash

# Echo commands as they are executed
set -x

# Variables
VM_NAME='debian-base'
VB_DIR="${HOME}/vbox-vms"
VM_DIR="${VB_DIR}/${VM_NAME}"
SSH_PORT=30022

# Attempt cleanup
VBoxManage controlvm "${VM_NAME}" poweroff
VBoxManage unregistervm "${VM_NAME}" --delete
rm -rf "${VM_DIR}"

# From now on, exit on errors
set -e

# Download and extract
if [[ ! -f 'Debian_11.1.0_VBM.7z' ]]; then
  wget 'https://altushost-swe.dl.sourceforge.net/project/linuxvmimages/VirtualBox/D/11/Debian_11.1.0_VBM.7z'
fi
mkdir -p "${VM_DIR}"
7z x 'Debian_11.1.0_VBM.7z' -o"${VM_DIR}" -y

# Create VM and rename
VBoxManage registervm "${VM_DIR}/Debian_11.1.0_VBM_LinuxVMImages.COM.vbox"
VBoxManage modifyvm "Debian_11.1.0_VBM_LinuxVMImages.COM" --name "${VM_NAME}"

# Basic VM settings
VBoxManage modifyvm "${VM_NAME}" \
  --cpus 2 \
  --memory 4096 \
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
sshpass -p 'debian' ssh-copy-id \
  -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' \
  -p "${SSH_PORT}" -i freeipa_rsa debian@localhost

# Provision
scp -F ssh_config -r 00-debian-base/* debian-base:/home/debian
ssh -F ssh_config debian-base sudo /home/debian/provision.sh

# Take a snapshot that can be used to set up other Debian machines.
# Make sure the snapshot is taken with the machine completely off
VBoxManage controlvm "${VM_NAME}" acpipowerbutton
sleep 10
VBoxManage snapshot "${VM_NAME}" take 'clone-me'
VBoxManage snapshot "${VM_NAME}" list
