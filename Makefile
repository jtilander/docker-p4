.PHONY: iterate clean all kill build log up

DC=docker-compose

iterate: kill build up log

build:
	$(DC) build

kill:
	$(DC) stop && $(DC) rm -f

up:
	$(DC) up -d

log:
	$(DC) logs
