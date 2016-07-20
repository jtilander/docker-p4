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

if [ -f $P4ROOT/.initialized ]; then
	exit 0
fi

NAME="${NAME:-$HOSTNAME}"

export P4PASSWD=$P4PASSWD
export P4USER=$P4USER
export P4PORT=$P4PORT

echo "Initialize server with default tables and users."
echo NAME: $NAME
echo P4PORT: $P4PORT
echo P4USER: $P4USER
echo P4ROOT: $P4ROOT

touch ~perforce/.p4config
chmod 0600 ~perforce/.p4config
chown perforce:perforce ~perforce/.p4config

cat > ~perforce/.p4config <<EOF
P4USER=$P4USER
P4PORT=$P4PORT
P4PASSWD="$P4PASSWD"
EOF

cd ~perforce

/opt/perforce/sbin/configure-helix-p4d.sh $NAME -n -p $P4PORT -r $P4ROOT -u $P4USER -P "${P4PASSWD}" --case $CASE_INSENSITIVE

p4 info

echo "$P4PASSWD"|p4 login

p4 info

p4dctl stop -t p4d $NAME

touch $P4ROOT/.initialized
