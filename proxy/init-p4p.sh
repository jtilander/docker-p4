#!/bin/bash
#set -evx
set -e

IPADDRESSES=`hostname -I`
echo "IP Addresses: $IPADDRESSES"
echo -n "Primary address: "
ifconfig `ip route | grep default | head -1 | sed 's/\(.*dev \)\([a-z0-9]*\)\(.*\)/\2/g'` | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1

if [ -f /data/.initialized ]; then
    exit 0
fi

mkdir -p $P4CACHE
mkdir -p /data/client
mkdir -p /data/scripts

touch /data/.initialized
