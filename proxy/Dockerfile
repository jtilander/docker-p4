FROM phusion/baseimage:0.9.18
MAINTAINER Jim Tilander <jim@tilander.org>

ARG P4P_VERSION=16.2

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

RUN apt-get install -yq --no-install-recommends -q helix-cli

# Cleanup APT when we are done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -fsSL -O http://cdist2.perforce.com/perforce/r${P4P_VERSION}/bin.linux26x86_64/p4p && mv p4p /usr/bin/p4p && chmod +x /usr/bin/p4p

# Environment configurations
ENV P4CONFIG=.p4config
ENV P4CACHE=/data/cache
ENV P4PORT=1666
ENV P4TARGET=perforce:1666
ENV P4PASSWD=
ENV P4USER=p4admin
ENV P4CLIENT=p4p_populate_ws
ENV CACHE_MAX_SIZE_MB=1048576
ENV CACHE_MAX_EMPTY_MB=51200
ENV PARALLEL_SYNC=

ADD cache_* /usr/local/bin/
RUN chmod a+x /usr/local/bin/cache_*

VOLUME /data
EXPOSE 1666

RUN mkdir -p /etc/my_init.d
ADD init-p4p.sh /etc/my_init.d/p4p.sh

RUN mkdir -p /etc/service/p4p
ADD run-p4p.sh /etc/service/p4p/run

RUN echo "*/10 * * * * root bash -l -c /usr/local/bin/cache_clean.sh" > /etc/cron.d/perforce-proxy-clean
RUN echo "*/5 * * * * root bash -l -c /usr/local/bin/cache_populate.sh" > /etc/cron.d/perforce-proxy-populate
