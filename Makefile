# Makefile for llvm-mingw Docker images
#
# Builds a matrix of Go versions x llvm-mingw versions for Ubuntu and Alpine.
#
# Usage:
#   make build-all              Build all combinations
#   make build-ubuntu           Build all Ubuntu combos
#   make build-alpine           Build all Alpine combos
#   make build-ubuntu-go1.22.5-llvm20260616   Single image
#   make build-alpine-go1.22.5-llvm20260616   Single image
#   make push                   Push all to registry
#   make list                   List available combinations
#   make clean                  Remove local images
#
# Override versions:
#   make build-all GO_VERSIONS="1.22.5 1.23.0" LLVM_VERSIONS="20260616 20260519"

SHELL := /bin/bash

# ---- Configurable ----
GO_VERSIONS   ?= 1.24.13 1.25.11 1.26.4
LLVM_VERSIONS ?= 20260616 20260519 20260421 20260324 20260224 20251216 20251104 20250910 20250709 20250514 20250417
REGISTRY      ?= ghcr.io/aldok10
IMAGE_NAME    ?= golang-llvm-mingw-compiler

# ---- Help ----
.DEFAULT_GOAL := help

help:
	@echo "llvm-mingw Docker Build Matrix"
	@echo ""
	@echo "Targets:"
	@echo "  make build-all          Build all combinations"
	@echo "  make build-ubuntu       Build all Ubuntu images"
	@echo "  make build-alpine       Build all Alpine images"
	@echo "  make push               Push all images to $(REGISTRY)"
	@echo "  make push-ubuntu        Push Ubuntu images"
	@echo "  make push-alpine        Push Alpine images"
	@echo "  make list               List combinations"
	@echo "  make clean              Remove local images"
	@echo ""
	@echo "Examples:"
	@echo "  make build-ubuntu-22.04-go1.22.5-llvm20260616"
	@echo "  make build-alpine-go1.22.5-llvm20260616"
	@echo "  make build-all GO_VERSIONS='1.21.0 1.22.5' LLVM_VERSIONS='20260616 20260519'"
	@echo ""
	@echo "Go versions : $(GO_VERSIONS)"
	@echo "LLVM tags   : $(LLVM_VERSIONS)"
	@echo "Total       : $$(( $$(echo $(GO_VERSIONS) | wc -w) * $$(echo $(LLVM_VERSIONS) | wc -w) * 2 )) images"

# ---- List ----
list:
	@echo "=== Ubuntu ==="
	@for go in $(GO_VERSIONS); do for llvm in $(LLVM_VERSIONS); do echo "  ubuntu-22.04-go$${go}-llvm$${llvm}"; done; done
	@echo ""
	@echo "=== Alpine ==="
	@for go in $(GO_VERSIONS); do for llvm in $(LLVM_VERSIONS); do echo "  alpine-go$${go}-llvm$${llvm}"; done; done

# ---- Dynamic target generation ----
# Generate explicit targets for every (go, llvm) combination
# This avoids pattern-rule limitations with multiple wildcards.

UBUNTU_GO_TAGS   := $(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),ubuntu-22.04-go$(go)-llvm$(llvm)))
ALPINE_GO_TAGS   := $(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),alpine-go$(go)-llvm$(llvm)))

# Ubuntu build targets
define BUILD_UBUNTU
build-ubuntu-22.04-go$(1)-llvm$(2):
	@echo "=== ubuntu-22.04 go$(1) llvm$(2) ==="
	docker build -f Dockerfile.ubuntu \
		--build-arg GO_VERSION="$(1)" \
		--build-arg LLVM_VERSION="$(2)" \
		-t "$(IMAGE_NAME):ubuntu-22.04-go$(1)-llvm$(2)" \
		-t "$(REGISTRY)/$(IMAGE_NAME):ubuntu-22.04-go$(1)-llvm$(2)" \
		.
endef

$(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),$(eval $(call BUILD_UBUNTU,$(go),$(llvm)))))

# Alpine build targets
define BUILD_ALPINE
build-alpine-go$(1)-llvm$(2):
	@echo "=== alpine go$(1) llvm$(2) ==="
	docker build -f Dockerfile.alpine \
		--build-arg GO_VERSION="$(1)" \
		--build-arg LLVM_VERSION="$(2)" \
		-t "$(IMAGE_NAME):alpine-go$(1)-llvm$(2)" \
		-t "$(REGISTRY)/$(IMAGE_NAME):alpine-go$(1)-llvm$(2)" \
		.
endef

$(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),$(eval $(call BUILD_ALPINE,$(go),$(llvm)))))

# Ubuntu push targets
define PUSH_UBUNTU
push-ubuntu-22.04-go$(1)-llvm$(2): build-ubuntu-22.04-go$(1)-llvm$(2)
	docker push "$(REGISTRY)/$(IMAGE_NAME):ubuntu-22.04-go$(1)-llvm$(2)"
endef

$(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),$(eval $(call PUSH_UBUNTU,$(go),$(llvm)))))

# Alpine push targets
define PUSH_ALPINE
push-alpine-go$(1)-llvm$(2): build-alpine-go$(1)-llvm$(2)
	docker push "$(REGISTRY)/$(IMAGE_NAME):alpine-go$(1)-llvm$(2)"
endef

$(foreach go,$(GO_VERSIONS),$(foreach llvm,$(LLVM_VERSIONS),$(eval $(call PUSH_ALPINE,$(go),$(llvm)))))

# Ubuntu all-in-one
build-ubuntu: $(addprefix build-,$(UBUNTU_GO_TAGS))
	@echo "All Ubuntu images done."

push-ubuntu: $(addprefix push-,$(UBUNTU_GO_TAGS))
	@echo "All Ubuntu images pushed."

# Alpine all-in-one
build-alpine: $(addprefix build-,$(ALPINE_GO_TAGS))
	@echo "All Alpine images done."

push-alpine: $(addprefix push-,$(ALPINE_GO_TAGS))
	@echo "All Alpine images pushed."

# All
build-all: build-ubuntu build-alpine
	@echo "=== All images built ==="

push: push-ubuntu push-alpine
	@echo "=== All images pushed ==="

# ---- Clean ----
clean:
	@echo "Removing images..."
	@for tag in $(UBUNTU_GO_TAGS) $(ALPINE_GO_TAGS); do docker rmi "$(IMAGE_NAME):$$tag" 2>/dev/null || true; docker rmi "$(REGISTRY)/$(IMAGE_NAME):$$tag" 2>/dev/null || true; done
	@echo "Done."

.PHONY: help list build-all build-ubuntu build-alpine push push-ubuntu push-alpine clean
