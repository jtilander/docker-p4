#!/bin/bash
#set -exv
exec 1> >(logger -s -t $(basename $0)) 2>&1

set -e
(
	flock -n 200
	
	echo "Populating cache with files from $P4TARGET as user $P4USER on client $P4CLIENT"

	if [ -z $P4PASSWD ]; then
		echo "No P4PASSWD set for user $P4USER, skipping pre population."
		exit 0
	fi

	if [ -z $P4CLIENT ]; then
		echo "No P4CLIENT set for populating the proxy as user $P4USER, skipping pre population."
		exit 0
	fi

	echo $P4PASSWD|p4 -u $P4USER -p $P4PORT login
	time p4 -u $P4USER -p $P4PORT -c $P4CLIENT -Zproxyload sync

) 200>/tmp/.cache_populate.lock
