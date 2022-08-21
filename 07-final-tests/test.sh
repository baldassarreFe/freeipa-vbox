#!/usr/bin/env bash

# Exit on errors, echo commands as they are executed
set -e
set -x

# 1. Turn off server and wait for node01 to take notice
VBoxManage controlvm 'server' acpipowerbutton
sleep 30

# 2. Create a new user from node01
ssh -F ssh_config node01 bash -c 'kinit admin && ipa user-add userthree --first=User --last=Three --random'
# Password for admin@IPA.TEST: ...
# User login: userthree

# 3. Check that replica01 knows about the user
ssh -F ssh_config replica01 id 'userthree'
# uid=1256700501(userthree) gid=1256700501(userthree) groups=1256700501(userthree)

# 4. Turn on server and wait for FreeIPA to start and sync
VBoxManage startvm 'server' --type headless
sleep 60
ssh -F ssh_config server systemctl status ipa

# 5. Check that server also knows about the user (might have to wait a bit)
ssh -F ssh_config server id 'userthree'
