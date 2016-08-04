# You should set these environment variables in the parent
# shell that you run, or these will simply be set to nothing.
export LDAPSERVER ?= 
export LDAPBINDUSER ?= 
export LDAPBINDPASSWD ?= 
export LDAPSEARCHBASE ?= 

DOCKER_REPO ?= jtilander
DC=docker-compose

.PHONY: iterate clean all kill build log up image

iterate: kill build up log

build:
	$(DC) build

kill:
	$(DC) stop && $(DC) rm -f

up:
	$(DC) up -d

log:
	$(DC) logs -f




image:
	docker build -t $(DOCKER_REPO)/p4-server server
	docker build -t $(DOCKER_REPO)/p4-git-fusion git-fusion

serverup: networkup
	docker run -d --name p4-server --hostname p4server --net=perforce0 --ip 172.28.0.200 \
	-e "P4PASSWD=${P4PASSWD}" \
	-e "LDAPNAME=${LDAPNAME}" \
	-e "LDAPSERVER=${LDAPSERVER}" \
	-e "LDAPBINDUSER=${LDAPBINDUSER}" \
	-e "LDAPBINDPASSWD=${LDAPBINDPASSWD}" \
	-e "LDAPSEARCHBASE=${LDAPSEARCHBASE}" \
	-e "USE_GIT_FUSION=${USE_GIT_FUSION}" \
	-p 1666:1666 \
	-v /mnt/datavolumes/perforce-server/data:/data \
	-v /mnt/datavolumes/perforce-server/library:/library \
	jtilander/p4-server && docker logs -f p4-server

serverdown:
	docker stop p4-server && docker rm -f p4-server

networkup:
	docker network inspect perforce0 > /dev/null 2>&1 || docker network create --driver=bridge --subnet=172.28.0.0/16 --ip-range=172.28.0.0/16 --gateway=172.28.5.1 perforce0

networkdown:
	docker network rm perforce0

fusionup: networkup
	docker run -d --name p4-git --hostname p4git --net=perforce0 --ip 172.28.0.201 \
		-e "P4PASSWD=${P4PASSWD}" \
		-e "P4PORT=${P4PORT}" \
		-p 2222:22 \
		-v /mnt/datavolumes/perforce-git:/data \
		jtilander/p4-git-fusion && docker logs -f p4-git

fusiondown:
	docker stop p4-git && docker rm -f p4-git

proxyup: networkup
	docker run -d --name p4-proxy --hostname p4proxy --net=perforce0 --ip 172.28.0.202 \
		-e "P4PASSWD=${P4PASSWD}" \
		-e "P4TARGET=${P4TARGET}" \
		-e "P4CLIENT=${P4CLIENT}" \
		-e "CACHE_MAX_SIZE_MB=${CACHE_MAX_SIZE_MB}" \
		-e "CACHE_MAX_EMPTY_MB=${CACHE_MAX_EMPTY_MB}" \
		-p 1667:1666 \
		-v /mnt/datavolumes/perforce-proxy:/data \
		jtilander/p4-proxy && docker logs -f p4-proxy

proxydown:
	docker stop p4-proxy && docker rm -f p4-proxy

neat: serverdown networkdown



# In case you have a mac and vmware and want to setup your initial environment
provisionmac:
	brew install docker
	brew install docker-compose
	-docker-machine rm -f dockervm
	docker-machine create -d vmwarefusion --vmwarefusion-cpu-count 2 --vmwarefusion-memory-size 2048 dockervm
