# Set the shell to bash always
SHELL := /bin/bash

# Options
ORG_NAME=crossplanebook
PROVIDER_NAME=provider-template

# Package setup
PACKAGE=package
export PACKAGE
PACKAGE_REGISTRY=$(PACKAGE)/.registry
PACKAGE_REGISTRY_SOURCE=config/package/manifests

build: generate build-package test
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o ./bin/$(PROVIDER_NAME)-controller cmd/provider/main.go

image: generate build-package test
	docker build . -t $(ORG_NAME)/$(PROVIDER_NAME):latest -f cluster/Dockerfile

image-push:
	docker push $(ORG_NAME)/$(PROVIDER_NAME):latest

install:
	kubectl apply -f config/package/sample/install.package.yaml

install-local: image
	docker tag $(ORG_NAME)/$(PROVIDER_NAME):latest $(PROVIDER_NAME):local
	$(KIND) load docker-image $(PROVIDER_NAME):local
	kubectl apply -f config/package/sample/local.install.package.yaml

run: generate
	kubectl apply -f config/crd/ -R
	go run cmd/provider/main.go -d

all: image image-push install

generate:
	go generate ./...

tidy:
	go mod tidy

test:
	go test -v ./...

# ====================================================================================
# Package related targets

# Initialize the package folder
$(PACKAGE_REGISTRY):
	@mkdir -p $(PACKAGE_REGISTRY)/resources
	@touch $(PACKAGE_REGISTRY)/app.yaml $(PACKAGE_REGISTRY)/install.yaml

CRD_DIR=config/crd
build-package: clean $(PACKAGE_REGISTRY)
# Copy CRDs over
	@find $(CRD_DIR) -type f -name '*.yaml' | \
		while read filename ; do mkdir -p $(PACKAGE_REGISTRY)/resources/$$(basename $${filename%_*});\
		concise=$${filename#*_}; \
		cat $$filename > \
		$(PACKAGE_REGISTRY)/resources/$$( basename $${filename%_*} )/$$( basename $${concise/.yaml/.crd.yaml} ) \
		; done
	@cp -r $(PACKAGE_REGISTRY_SOURCE)/* $(PACKAGE_REGISTRY)

clean: clean-package

clean-package:
	@rm -rf $(PACKAGE)

# ====================================================================================
# Tools

KIND=$(shell which kind)

.PHONY: generate tidy build-package clean clean-package build image all install install-local run