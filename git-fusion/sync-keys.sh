#!/bin/bash
#set -exv
exec 1> >(logger -s -t $(basename $0)) 2>&1

export PATH=/opt/perforce/git-fusion/libexec:/opt/perforce/git-fusion/bin:$PATH

#echo "Running sync p4gf_auth_update_authorized_keys..."
/opt/perforce/git-fusion/libexec/p4gf_auth_update_authorized_keys.py
