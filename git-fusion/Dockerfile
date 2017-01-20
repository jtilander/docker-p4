FROM phusion/baseimage:0.9.18
MAINTAINER Jim Tilander <jim@tilander.org>

ENV FUSION_VERSION 2016.2-1398420~trusty

# Use the base image's standard init process
CMD ["/sbin/my_init"]

# Ensure that the apt tool doesn't require any user interaction
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -yq --no-install-recommends -q wget python openssh-server patch

# Add official perforce packages
RUN wget -qO - https://package.perforce.com/perforce.pubkey | apt-key add -
RUN echo 'deb http://package.perforce.com/apt/ubuntu trusty release' > /etc/apt/sources.list.d/perforce.list
RUN apt-get update

RUN apt-cache policy helix-git-fusion

RUN apt-get install -yq --no-install-recommends -q \
	helix-cli \
	helix-git-fusion-base=$FUSION_VERSION \
	helix-git-fusion-trigger=$FUSION_VERSION \
	helix-git-fusion=$FUSION_VERSION \
	helix-p4dctl

# Cleanup APT when we are done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Environment configurations
ENV P4CONFIG=.p4config P4PORT=1666 P4USER=p4admin P4ROOT=/data NAME=gf

VOLUME /data
EXPOSE 22 1666

# The configure script is not automated, since case sensitivity is still checked through a prompt. Fix.
ADD ./configure-git-fusion.sh.patch /opt/perforce/git-fusion/libexec/configure-git-fusion.sh.patch
RUN patch -u /opt/perforce/git-fusion/libexec/configure-git-fusion.sh /opt/perforce/git-fusion/libexec/configure-git-fusion.sh.patch

# Prepare the home directory to be a template that we can move into /data/git-fusion-home and relink it
# RUN mv /opt/perforce/git-fusion/home/perforce-git-fusion/p4gf_environment.cfg
RUN mv /opt/perforce/git-fusion/home /opt/perforce/git-fusion/home-template
RUN ln -s /data/gf-home /opt/perforce/git-fusion/home

RUN mkdir -p /etc/my_init.d
ADD init-git-fusion.sh /etc/my_init.d/git-fusion.sh

RUN rm -f /etc/service/sshd/down

ADD sync-keys.sh /usr/local/bin/
RUN echo "* * * * * git bash -l -c /usr/local/bin/sync-keys.sh" > /etc/cron.d/perforce-git-fusion-sync-keys
RUN echo "" >> /etc/cron.d/perforce-git-fusion-sync-keys

RUN mv /etc/perforce /etc/perforce.orig
RUN ln -s /data/etc/perforce /etc/perforce

RUN sed -i 's@#PasswordAuthentication no@PasswordAuthentication no@' /etc/ssh/sshd_config
