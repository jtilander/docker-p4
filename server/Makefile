.PHONY: diff patch image

DOCKER_REPO ?= jtilander
P4D_VERSION ?= 2016.2-1468155~trusty
TAG ?= test

image:
	docker build -t $(DOCKER_REPO)/p4-server:$(TAG) --build-arg P4D_VERSION=$(P4D_VERSION) .

push:
	docker push $(DOCKER_REPO)/p4-server:$(TAG)