.PHONY: diff patch image

DOCKER_REPO ?= jtilander
GF_VERSION ?= 2016.2-1398420~trusty
TAG ?= test

image:
	docker build -t $(DOCKER_REPO)/p4-git-fusion:$(TAG) --build-arg GF_VERSION=$(GF_VERSION) .

push:
	docker push $(DOCKER_REPO)/p4-git-fusion:$(TAG)


diff:
	diff -u configure-git-fusion.sh.orig configure-git-fusion.sh > configure-git-fusion.sh.patch || true
	cat configure-git-fusion.sh.patch

patch:
	patch -u configure-git-fusion.sh.test configure-git-fusion.sh.patch
