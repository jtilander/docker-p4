FROM phusion/baseimage:0.9.18
MAINTAINER Jim Tilander <jim@tilander.org>

ENV P4D_VERSION 2016.2-1487173~trusty

# Use the base image's standard init process
CMD ["/sbin/my_init"]

# Ensure that the apt tool doesn't require any user interaction
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -yq --no-install-recommends -q wget python gettext-base

# Add official perforce packages
RUN wget -qO - https://package.perforce.com/perforce.pubkey | apt-key add -
RUN echo 'deb http://package.perforce.com/apt/ubuntu trusty release' > /etc/apt/sources.list.d/perforce.list
RUN apt-get update

RUN apt-cache policy helix-p4d

RUN apt-get install -yq --no-install-recommends -q helix-cli helix-p4d=$P4D_VERSION helix-p4dctl helix-git-fusion-trigger

# Cleanup APT when we are done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Environment configurations
ENV NAME=p4depot P4CONFIG=.p4config P4ROOT=/data/p4depot P4PORT=1666 P4USER=p4admin
ENV CASE_INSENSITIVE=1
ENV ENABLE_AUTOCHECKPOINTS=1
ENV LDAPSERVER=
ENV LDAPNAME=search
ENV LDAPBINDUSER=
ENV LDAPBINDPASSWD=
ENV LDAPSEARCHBASE=
ENV USE_GIT_FUSION=1

# Data is where the depot database goes
# Library is where the library files for perforce goes. Symlinks at boot will set this up.
VOLUME /data
VOLUME /library
EXPOSE 1666

ADD ./p4-*.txt /root/

# Add the daily checkpoint backup cron job to the mix.
ADD ./perforce-checkpoint.?? /usr/local/bin/
RUN chmod a+x /usr/local/bin/perforce-checkpoint.??

RUN mkdir -p /etc/my_init.d
ADD init-p4d.sh /etc/my_init.d/p4d.sh

RUN mkdir -p /etc/service/p4d
ADD run-p4d.sh /etc/service/p4d/run

RUN mv /etc/perforce /etc/perforce.orig
RUN ln -s /data/etc/perforce /etc/perforce

RUN mv /opt/perforce/git-fusion/libexec /opt/perforce/git-fusion/libexec_template

