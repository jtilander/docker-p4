#!/bin/bash
#set -exv
exec 1> >(logger -s -t $(basename $0)) 2>&1

export PATH=/opt/perforce/git-fusion/libexec:/opt/perforce/git-fusion/bin:$PATH

#source /opt/perforce/git-fusion/home/perforce-git-fusion/.perforce-env
#echo "$P4PASSWD"|p4 login

/opt/perforce/git-fusion/libexec/p4gf_auth_update_authorized_keys.py
