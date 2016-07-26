.PHONY: diff patch image

DOCKER_REPO ?= jtilander

image:
	docker build -t $(DOCKER_REPO)/p4-git-fusion .

diff:
	diff -u configure-git-fusion.sh.orig configure-git-fusion.sh > configure-git-fusion.sh.patch || true
	cat configure-git-fusion.sh.patch

patch:
	patch -u configure-git-fusion.sh.test configure-git-fusion.sh.patch
