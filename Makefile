# This is the makefile for the `osbuild-getting-started` project, abbreviated
# as `ogsc`.
#
# It provides a quick (containerized) setup of the `osbuild` ecosystem.

PREFIX=ogsc
PREFIX_BUILD=$(PREFIX)-build
PREFIX_RUN=$(PREFIX)-run

osbuild_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/osbuild | tail -n1 | cut -d/ -f3 | cut -d^ -f1)
osbuild_composer_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/osbuild-composer | tail -n1 | cut -d/ -f3 | cut -d^ -f1)
weldr_client_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/weldr-client | tail -n1 | cut -d/ -f3 | cut -d^ -f1)

osbuild_version_x=$(shell echo $(osbuild_version) | sed -e s/v//g)
osbuild_composer_version_x=$(shell echo $(osbuild_composer_version) | sed -e s/v//g)
weldr_client_version_x=$(shell echo $(weldr_client_version) | sed -e s/v//g)

.PHONY: setup-host
setup-host:
	./bin/setup-host.py container

.PHONY: setup-share
setup-share:
	./bin/setup-share.py container

.PHONY: build-osbuild 
build-osbuild:
	podman image exists $(PREFIX_BUILD)-osbuild:$(osbuild_version) || podman build \
		--build-arg osbuild_version=$(osbuild_version) \
		-t $(PREFIX_BUILD)-osbuild:$(osbuild_version) \
		src/ogsc-build-osbuild

.PHONY: rpms-osbuild 
rpms-osbuild: build-osbuild
	ls $(shell pwd)/build/rpms/osbuild-$(osbuild_version_x)-*.rpm || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild/rpmbuild/RPMS/noarch/:rw,Z \
		$(PREFIX_BUILD)-osbuild:$(osbuild_version) \
		make rpm

.PHONY: build-osbuild-composer
build-osbuild-composer:
	podman image exists $(PREFIX_BUILD)-osbuild-composer:$(osbuild_composer_version) || podman build \
		--build-arg osbuild_composer_version=$(osbuild_composer_version) \
		-t $(PREFIX_BUILD)-osbuild-composer:$(osbuild_composer_version) \
		src/ogsc-build-osbuild-composer

.PHONY: rpms-osbuild-composer
rpms-osbuild-composer: build-osbuild-composer
	ls $(shell pwd)/build/rpms/osbuild-composer-$(osbuild_composer_version_x)-* || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild-composer/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)-osbuild-composer:$(osbuild_composer_version) \
		make scratch

.PHONY: build-weldr-client
build-weldr-client:
	podman image exists $(PREFIX_BUILD)-weldr-client:$(weldr_client_version) || podman build \
		--build-arg weldr_client_version=$(weldr_client_version) \
		-t $(PREFIX_BUILD)-weldr-client:$(weldr_client_version) \
		src/ogsc-build-weldr-client

.PHONY: rpms-weldr-client
rpms-weldr-client: build-weldr-client
	ls $(shell pwd)/build/rpms/weldr-client-$(weldr_client_version_x)-* || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/weldr-client/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)-weldr-client:$(weldr_client_version) \
		make scratch-rpm

.PHONY: ogsc-composer
ogsc-composer:
	podman image exists $(PREFIX_RUN)-composer:$(osbuild_composer_version) || podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		-t $(PREFIX_RUN)-composer:$(osbuild_composer_version) \
		src/ogsc-composer

.PHONY: ogsc-worker
ogsc-worker:
	podman image exists $(PREFIX_RUN)-worker:$(osbuild_composer_version) || podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		-t $(PREFIX_RUN)-worker:$(osbuild_composer_version) \
		src/ogsc-worker

.PHONY: ogsc-cli
ogsc-cli:
	podman image exists $(PREFIX_RUN)-cli:$(weldr_client_version) || podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg weldr_client_version=${weldr_client_version_x} \
		-t $(PREFIX_RUN)-cli:$(weldr_client_version) \
		src/ogsc-cli

.PHONY: quick
quick: rpms-osbuild rpms-osbuild-composer rpms-weldr-client ogsc-composer ogsc-worker ogsc-cli

.PHONY: run
run: setup-share quick
	echo "hi"

.PHONY: clean
clean:
	podman image rm -f $(shell podman image ls "ogsc*" -q)
	rm $(shell pwd)/build/rpms/*.rpm
