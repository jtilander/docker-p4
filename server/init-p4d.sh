#!/bin/bash
#set -evx
set -e

#
# Copy standard configuration files over to the volume
#
if [ ! -d /data/etc ]; then
	echo First time installation, copying configuration from /etc/perforce to /data/etc and relinking
	mkdir -p /data/etc
	cp -r /etc/perforce/* /data/etc/
fi 
mv /etc/perforce /etc/perforce.orig
ln -s /data/etc /etc/perforce

#
# Optionally enable taking checkpoints each day
#
if [ "$ENABLE_AUTOCHECKPOINTS" -eq "1" ]; then
	if [ ! -f /etc/cron.daily/perforcecheckpoint ]; then
		ln -s /usr/local/bin/perforce-checkpoint.sh /etc/cron.daily/perforcecheckpoint
	fi
fi

P4SSLDIR="$P4ROOT/ssl"

for DIR in $P4ROOT $P4SSLDIR; do
    mkdir -m 0700 -p $DIR
    chown perforce:perforce $DIR
done

#
# Configure the server.
#
if [ -z "$P4PASSWD" ]; then
    WARN=1
    P4PASSWD=DhP5rYyBgz
fi

echo "   P4USER=$P4USER (the admin user)"
if [ -n "$WARN" ]; then
    echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
    echo "Please change as soon as possible:"
    echo "   P4PASSWD=$P4PASSWD"
    echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
fi

IPADDRESSES=`hostname -I`
echo "IP Addresses: $IPADDRESSES"
echo -n "Primary address: "
ifconfig `ip route | grep default | head -1 | sed 's/\(.*dev \)\([a-z0-9]*\)\(.*\)/\2/g'` | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1

if [ -f $P4ROOT/.initialized ]; then
    p4dctl start -t p4d $NAME
    
    # Ensure that we have a .p4tickets file if someone wants to debug the server itself.
    echo $P4PASSWD|/usr/bin/p4 -u $P4USER -p $P4PORT login

    # Show the configuration for the server.
    /usr/bin/p4 -u $P4USER -p $P4PORT info 

    p4dctl stop -t p4d $NAME
    
    exit 0
fi

# Create a link to the depot library files so that we can separate db and library files onto
# different volumes.
ln -s ../../library/depot $P4ROOT/depot
mkdir -p $P4ROOT/../../library/depot

NAME="${NAME:-$HOSTNAME}"

/opt/perforce/sbin/configure-helix-p4d.sh $NAME -n -p $P4PORT -r $P4ROOT -u $P4USER -P $P4PASSWD --case $CASE_INSENSITIVE
p4dctl start -t p4d $NAME

P4TICKET=`echo "$P4PASSWD"|/usr/bin/p4 login -a -p|sed -r -e "s/Enter password://g"`
echo $P4TICKET
P4="/usr/bin/p4 -u $P4USER -p $P4PORT -P $P4TICKET"

$P4 configure show

$P4 user -i < /root/p4-users.txt
$P4 group -i < /root/p4-groups.txt
$P4 group -i < /root/p4-admins.txt
$P4 protect -i < /root/p4-protect.txt

if [ ! -z "$LDAPSERVER" ]; then

    # http://answers.perforce.com/articles/KB/2590
    # http://answers.perforce.com/articles/KB/14994

    cat /root/p4-ldap-$LDAPNAME.txt | envsubst | $P4 ldap -i

    $P4 ldap -o $LDAPNAME

    $P4 configure set auth.ldap.order.1=$LDAPNAME
    $P4 configure set auth.default.method=ldap
    
    # You still have to add the user manually to the protection table for them to be able to login.
    $P4 configure set auth.ldap.userautocreate=1
fi

# Enable by default "p4 monitor" command
$P4 configure set monitor=2

# Increase the default buffer sizes
$P4 configure set net.tcpsize=524288
$P4 configure set filesys.bufsize=524288

# By default set the max parallel syncs to 5
$P4 configure set net.parallel.max=5

$P4 configure set net.parallel.submit.threads=8
$P4 configure set net.parallel.submit.min=9
$P4 configure set net.parallel.submit.batch=8

#If non-zero, disable the sending of TCP keepalive packets.
#$P4 configure set net.keepalive.disable=0

#Idle time (in seconds) before starting to send keepalives.
#$P4 configure set net.keepalive.idle=0

#Interval (in seconds) between sending keepalive packets.
#$P4 configure set net.keepalive.interval=0

#Number of unacknowledged keepalives before failure.
#$P4 configure set net.keepalive.count=0

# Setup readonly client support
mkdir -p $P4ROOT/ro
$P4 configure set client.readonly.dir=$P4ROOT/ro

# Buffer size for read/write operations to server's archive of versioned files.
$P4 configure set lbr.bufsize=64k

# Explicit user command creates user.
$P4 configure set dm.user.noautocreate=3

# Improving concurrency with lockless reads
$P4 configure set db.peeking=2
#$P4 configure set server.locks.sync=1

# Ensure that we have a .p4tickets file if someone wants to debug the server itself.
echo $P4PASSWD|$P4 login

p4dctl stop -t p4d $NAME

touch $P4ROOT/.initialized
