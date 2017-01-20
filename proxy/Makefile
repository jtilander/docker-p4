.PHONY: image

DOCKER_REPO ?= jtilander
P4P_VERSION ?= 16.2
TAG ?= test

image:
	docker build -t $(DOCKER_REPO)/p4-proxy:$(TAG) --build-arg P4P_VERSION=$(P4P_VERSION) .

push:
	docker push $(DOCKER_REPO)/p4-proxy:$(TAG)

run:
	docker run --rm -p 1667:1666 $(DOCKER_REPO)/p4-proxy:$(TAG)

