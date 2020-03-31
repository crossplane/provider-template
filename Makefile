# Set the shell to bash always
SHELL := /bin/bash

# Options
ORG_NAME=crossplanebook
PROVIDER_NAME=provider-template

# Stack setup
STACK_PACKAGE=stack-package
export STACK_PACKAGE
STACK_PACKAGE_REGISTRY=$(STACK_PACKAGE)/.registry
STACK_PACKAGE_REGISTRY_SOURCE=config/stack/manifests

build: generate build-stack-package test
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o ./bin/$(PROVIDER_NAME)-controller cmd/provider/main.go

image: generate build-stack-package test
	docker build . -t $(ORG_NAME)/$(PROVIDER_NAME):latest -f cluster/Dockerfile

image-push:
	docker push $(ORG_NAME)/$(PROVIDER_NAME):latest

install:
	kubectl apply -f config/stack/sample/install.stack.yaml

install-local: image
	docker tag $(ORG_NAME)/$(PROVIDER_NAME):latest $(PROVIDER_NAME):local
	$(KIND) load docker-image $(PROVIDER_NAME):local
	kubectl apply -f config/stack/sample/local.install.stack.yaml

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
# Stacks related targets

# Initialize the stack package folder
$(STACK_PACKAGE_REGISTRY):
	@mkdir -p $(STACK_PACKAGE_REGISTRY)/resources
	@touch $(STACK_PACKAGE_REGISTRY)/app.yaml $(STACK_PACKAGE_REGISTRY)/install.yaml

CRD_DIR=config/crd
build-stack-package: clean $(STACK_PACKAGE_REGISTRY)
# Copy CRDs over
	@find $(CRD_DIR) -type f -name '*.yaml' | \
		while read filename ; do mkdir -p $(STACK_PACKAGE_REGISTRY)/resources/$$(basename $${filename%_*});\
		concise=$${filename#*_}; \
		cat $$filename > \
		$(STACK_PACKAGE_REGISTRY)/resources/$$( basename $${filename%_*} )/$$( basename $${concise/.yaml/.crd.yaml} ) \
		; done
	@cp -r $(STACK_PACKAGE_REGISTRY_SOURCE)/* $(STACK_PACKAGE_REGISTRY)

clean: clean-stack-package

clean-stack-package:
	@rm -rf $(STACK_PACKAGE)

# ====================================================================================
# Tools

KIND=$(shell which kind)

.PHONY: generate tidy build-stack-package clean clean-stack-package build image all install install-local run