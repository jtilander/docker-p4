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
	$(DC) logs




image:
	docker build -t $(DOCKER_REPO)/p4-server server

serverup: networkup
	docker run -d --name p4-server --hostname p4server --net=perforce0 --ip 172.28.0.200 -e "LDAPSERVER=${LDAPSERVER}" -p 1666:1666 -v /mnt/datavolumes/perforce-server/data:/data -v /mnt/datavolumes/perforce-server/library:/library jtilander/p4-server && docker logs -f p4-server

serverdown:
	docker stop p4-server && docker rm -f p4-server

networkup:
	docker network inspect perforce0 > /dev/null 2>&1 || docker network create --driver=bridge --subnet=172.28.0.0/16 --ip-range=172.28.0.0/16 --gateway=172.28.5.1 perforce0

networkdown:
	docker network rm perforce0

neat: serverdown networkdown
