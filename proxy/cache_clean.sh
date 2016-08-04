#!/bin/bash
#set -exv
exec 1> >(logger -s -t $(basename $0)) 2>&1

set -e
(
	flock -n 200

	time perl /usr/local/bin/cache_clean.pl -c $P4CACHE -l $CACHE_MAX_SIZE_MB -m $CACHE_MAX_EMPTY_MB

) 200>/tmp/.cache_clean.lock 
