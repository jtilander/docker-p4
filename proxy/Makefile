.PHONY: image

DOCKER_REPO ?= jtilander
P4P_VERSION ?= 16.2

image:
	docker build -t $(DOCKER_REPO)/p4-proxy --build-arg P4P_VERSION=$(P4P_VERSION) .

run:
	docker run --rm -p 1667:1666 $(DOCKER_REPO)/p4-proxy

