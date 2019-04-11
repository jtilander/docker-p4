#!/bin/bash
#set -evx
set -e

#
# Copy standard configuration files over to the volume
#
if [ ! -d /data/etc/perforce ]; then
	echo First time installation, copying configuration from /etc/perforce to /data/etc/perforce and relinking
	mkdir -p /data/etc/perforce
	cp -r /etc/perforce.orig/* /data/etc/perforce/
fi 

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

NAME="${NAME:-$HOSTNAME}"
GFHOME=/opt/perforce/git-fusion/home

IPADDRESSES=`hostname -I`
echo "IP Addresses: $IPADDRESSES"
echo -n "Primary address: "
ifconfig `ip route | grep default | head -1 | sed 's/\(.*dev \)\([a-z0-9]*\)\(.*\)/\2/g'` | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -1

if [ ! -d /data/gf-home ]; then
    mkdir -p /data/gf-home
    mv /opt/perforce/git-fusion/home-template/* /data/gf-home/
fi    

if [ -e $P4ROOT/.initialized-fusion ]; then
    # Restore the host keys
    cp -f /data/sshkeys/ssh_host* /etc/ssh/

    # The git fusion configuration script adds these, but since we might have recreated the container
    # the changes got lost.
    if ! grep git /etc/passwd > /dev/null; then
        echo "git:x:999:999:Helix Git Fusion:/opt/perforce/git-fusion/home/perforce-git-fusion:/bin/bash" >> /etc/passwd
    fi

    if ! grep git /etc/shadow > /dev/null; then
        echo "git:$6$rFdhmMms$6dFyhSzxA5RTkfiBV3uC2W/hrV9UmRdLk7vPF9E8wqgJvykVZsFfDUmOedCVX28WeK9GWJzIRsaYOz5AgDWjO/:17009::::::" >> /etc/shadow
    else
        sed -i 's!git:.*!git:$6$rFdhmMms$6dFyhSzxA5RTkfiBV3uC2W/hrV9UmRdLk7vPF9E8wqgJvykVZsFfDUmOedCVX28WeK9GWJzIRsaYOz5AgDWjO/:17009::::::!' /etc/shadow
    fi


    # Restore the tickets since the perforce server might have changed.
    # TODO: Figure out what the ticket format is really about?
    su - git bash -c "echo $P4PASSWD|p4 -p $P4PORT -u git-fusion-user login"
    su - git bash -c "echo $P4PASSWD|p4 -p $P4PORT -u git-fusion-reviews-$NAME login"
    su - git bash -c "echo $P4PASSWD|p4 -p $P4PORT -u git-fusion-reviews--all-$NAME login"
    su - git bash -c "echo $P4PASSWD|p4 -p $P4PORT -u git-fusion-reviews--non-$NAME login"
 
    exit 0
fi

# Regenerate host keys
/etc/my_init.d/00_regen_ssh_host_keys.sh

mkdir -p /data/sshkeys
cp /etc/ssh/ssh_host* /data/sshkeys/

echo "Waiting for the perforce server to come up..."
sleep 3

P4TICKET=`echo "$P4PASSWD"|/usr/bin/p4 login -a -p $P4USER|sed -r -e "s/Enter password://g"`
echo $P4TICKET
P4="/usr/bin/p4 -u $P4USER -p $P4PORT -P $P4TICKET"

echo yes|/opt/perforce/git-fusion/libexec/configure-git-fusion.sh -n \
    --super $P4USER \
    --superpassword "$P4PASSWD" \
    --gfp4password "$P4PASSWD" \
    --p4port $P4PORT \
    --timezone ${TZ:-UTC} \
    --server remote \
    --id $NAME \
    --unknownuser unknown

rm /etc/cron.d/perforce-git-fusion

cat > /opt/perforce/git-fusion/home/perforce-git-fusion/.perforce-env <<EOF
export P4USER=$P4USER
export P4PASSWD=$P4PASSWD
export P4PORT=$P4PORT
EOF

sed -i 's!git:.*!git:$6$rFdhmMms$6dFyhSzxA5RTkfiBV3uC2W/hrV9UmRdLk7vPF9E8wqgJvykVZsFfDUmOedCVX28WeK9GWJzIRsaYOz5AgDWjO/:17009::::::!' /etc/shadow

touch $P4ROOT/.initialized-fusion
