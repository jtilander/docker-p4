.PHONY: image

DOCKER_REPO ?= jtilander

image:
	docker build -t $(DOCKER_REPO)/p4-proxy .

run:
	docker run --rm -p 1667:1666 $(DOCKER_REPO)/p4-proxy

