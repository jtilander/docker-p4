#!/bin/bash
#set -evx
set -e

P4SSLDIR="$P4ROOT/ssl"

resolve_password() {
    local DEFAULT_PASSWORD=DhP5rYyBgz
    if [ -z "$P4PASSWD" ]; then
        P4PASSWD=$DEFAULT_PASSWORD
    fi
    echo "   P4USER=$P4USER (the admin user)"
    if [ "$P4PASSWD" == "$DEFAULT_PASSWORD" ]; then
        echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
        echo "Please change as soon as possible:"
        echo "   P4PASSWD=$P4PASSWD"
        echo -e "\n***** WARNING: USING DEFAULT PASSWORD ******\n"
    fi
}

copy_standard_config() {
    if [ ! -d /data/etc/perforce ]; then
    	echo First time installation, copying configuration from /etc/perforce to /data/etc/perforce and relinking
    	mkdir -p /data/etc/perforce
    	cp -r /etc/perforce.orig/* /data/etc/perforce/
    fi 
}

enable_checkpoints() {
    if [ "$ENABLE_AUTOCHECKPOINTS" -eq "1" ]; then
    	if [ ! -f /etc/cron.daily/perforcecheckpoint ]; then
    		ln -s /usr/local/bin/perforce-checkpoint.sh /etc/cron.daily/perforcecheckpoint
    	fi
    fi
}

fix_permissions() {
    for DIR in $P4ROOT $P4SSLDIR; do
        mkdir -m 0700 -p $DIR
        chown perforce:perforce $DIR
    done
}

print_network_info() {
    local IPADDRESSES=`hostname -I`
    echo "IP Addresses: $IPADDRESSES"
    echo -n "Primary address: "
    ifconfig `ip route | grep default | head -1 | sed 's/\(.*dev \)\([a-z0-9]*\)\(.*\)/\2/g'` | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1
}

create_login_ticket() {
    p4dctl start -t p4d $NAME
        
    # Ensure that we have a .p4tickets file if someone wants to debug the server itself.
    echo $P4PASSWD|/usr/bin/p4 -u $P4USER -p $P4PORT login

    # Show the configuration for the server.
    /usr/bin/p4 -u $P4USER -p $P4PORT info 

    p4dctl stop -t p4d $NAME
}


split_lib_and_db() {
    # Create a link to the depot library files so that we can separate db and library files onto
    # different volumes.
    if [ ! -L $P4ROOT/depot ]; then
        ln -s ../../library/depot $P4ROOT/depot
    fi
    mkdir -p $P4ROOT/../../library/depot
}

create_git_fusion_trigger() {
    local P4=$1
    echo "Waiting for the git fusion server to initialize..."
    while [ `$P4 users | grep git-fusion-user | wc -l` -lt 1 ]; do
        echo "Waiting for git fusion..."
        sleep 5
    done

    echo "Installing support for git fusion triggers"

    if [ ! -d /data/gf-libexec ]; then
        mv /opt/perforce/git-fusion/libexec_template /data/gf-libexec
    fi

    ln -s /data/gf-libexec /opt/perforce/git-fusion/libexec

    if [ ! -f $P4ROOT/.gf-triggers-initialized ]; then
        python3 /opt/perforce/git-fusion/libexec/p4gf_submit_trigger.py --install $P4PORT $P4USER $P4PASSWD
        touch $P4ROOT/.gf-triggers-initialized
    fi
    
    # Ensure that the git user can login.
    echo $P4PASSWD|/usr/bin/p4 -u git-fusion-user -p $P4PORT login
}

initialize_commit_server() {

    echo "Initializing p4d master server for the first time..."

    local NAME=$1

    split_lib_and_db

    /opt/perforce/sbin/configure-helix-p4d.sh $NAME -n -p $P4PORT -r $P4ROOT -u $P4USER -P $P4PASSWD --case $CASE_INSENSITIVE
    p4dctl start -t p4d $NAME

    local P4TICKET=`echo "$P4PASSWD"|/usr/bin/p4 login -a -p|sed -r -e "s/Enter password://g"`
    echo $P4TICKET
    local P4="/usr/bin/p4 -u $P4USER -p $P4PORT -P $P4TICKET"

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

    $P4 configure set security=1

    # Enable by default "p4 monitor" command
    $P4 configure set monitor=2

    # Increase the default buffer sizes
    $P4 configure set net.tcpsize=524288
    $P4 configure set filesys.bufsize=524288

    # By default set the max parallel syncs
    $P4 configure set net.parallel.max=10

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

    $P4 configure set triggers.io=0

    $P4 configure set security=3


    # Install git-fusion trigger support, but make sure that we do this after the fusion server has initialized.
    if [ "$USE_GIT_FUSION" -eq "1" ]; then
        create_git_fusion_trigger $P4
    fi

    # Ensure that we have a .p4tickets file if someone wants to debug the server itself.
    echo $P4PASSWD|$P4 login

    create_login_ticket

    p4dctl stop -t p4d $NAME

    touch $P4ROOT/.initialized
}

resolve_password
copy_standard_config
enable_checkpoints
fix_permissions
print_network_info

if [ ! -f $P4ROOT/.initialized ]; then
    initialize_commit_server ${NAME:-$HOSTNAME}
fi
