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
	$(MAKE) -C server image
	$(MAKE) -C proxy image
	$(MAKE) -C git-fusion image

serverup:
	$(DC) up server && $(DC) logs -f server

serverdown:
	$(DC) stop server

fusionup:
	$(DC) up fusion

fusiondown:
	$(DC) down fusion

proxyup:
	$(DC) up proxy && $(DC) logs -f proxy

proxydown:
	$(DC) stop proxy

neat:
	$(DC) down


# In case you have a mac and vmware and want to setup your initial environment
provisionmac:
	brew install docker
	brew install docker-compose
	-docker-machine rm -f dockervm
	docker-machine create -d vmwarefusion --vmwarefusion-cpu-count 2 --vmwarefusion-memory-size 2048 dockervm
