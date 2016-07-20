#!/bin/bash
exec 1> >(logger -s -t $(basename $0)) 2>&1

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export MAX_HISTORY=20

#p4d -r $P4ROOT -z -jc

MYSCRIPT=`readlink $0`

if [ -z "$MYSCRIPT" ]; then
	MYSCRIPT=$0
fi

python `dirname $MYSCRIPT`/perforce-checkpoint.py $P4ROOT $MAX_HISTORY
