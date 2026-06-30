# Makefile for llvm-mingw Docker images
#
# Builds a matrix of Go versions x llvm-mingw versions for Ubuntu and Alpine.
# Both Go and LLVM versions accept major.minor format — latest patch is
# auto-resolved from upstream (go.dev and GitHub releases).
#
# Usage:
#   make build-all              Build all combinations
#   make build-ubuntu           Build all Ubuntu combos
#   make build-alpine           Build all Alpine combos
#   make build-ubuntu-go1.26-llvm22.1   Single (major.minor shorthand)
#   make push                   Push all to registry
#   make list                   List available combinations
#   make clean                  Remove local images
#
# Override versions:
#   make build-all GO_VERSIONS="1.24 1.25" LLVM_VERSIONS="22.1 21.1"

SHELL := /bin/bash

# ---- Configurable (major.minor only - patch auto-resolved) ----
GO_VERSIONS    ?= 1.24 1.25 1.26
LLVM_VERSIONS  ?= 22.1 21.1
REGISTRY       ?= ghcr.io/aldok10
IMAGE_NAME     ?= golang-llvm-mingw-compiler

# ---- Auto-resolve Go patch versions ----
# For each major.minor, fetch go.dev and find the latest patch.
RESOLVED_GO := $(shell python3 scripts/resolve-go-versions.py $(GO_VERSIONS) 2>/dev/null)
ifeq ($(strip $(RESOLVED_GO)),)
RESOLVED_GO := $(GO_VERSIONS)
endif

# ---- Auto-resolve LLVM-mingw release tags ----
# For each LLVM major.minor, fetch GitHub releases and find the latest tag.
RESOLVED_LLVM := $(shell python3 scripts/resolve-llvm-versions.py $(LLVM_VERSIONS) 2>/dev/null)
ifeq ($(strip $(RESOLVED_LLVM)),)
RESOLVED_LLVM := $(LLVM_VERSIONS)
endif

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
	@echo "  make build-ubuntu-22.04-go1.26-llvm22.1    (major.minor shorthand)"
	@echo "  make build-alpine-go1.26-llvm22.1           (major.minor shorthand)"
	@echo "  make build-all GO_VERSIONS='1.24 1.25' LLVM_VERSIONS='22.1 21.1'"
	@echo ""
	@echo "Go requested    : $(GO_VERSIONS)"
	@echo "Go resolved     : $(RESOLVED_GO)"
	@echo "LLVM requested  : $(LLVM_VERSIONS)"
	@echo "LLVM resolved   : $(RESOLVED_LLVM)"
	@echo "Total images    : $$(( $$(echo $(RESOLVED_GO) | wc -w) * $$(echo $(RESOLVED_LLVM) | wc -w) * 2 ))"

# ---- List ----
list:
	@echo "=== Resolved versions ==="
	@echo "Go  : $(RESOLVED_GO)"
	@echo "LLVM: $(RESOLVED_LLVM)"
	@echo ""
	@echo "=== Ubuntu ==="
	@for go in $(RESOLVED_GO); do for llvm in $(RESOLVED_LLVM); do echo "  ubuntu-22.04-go$${go}-llvm$${llvm}"; done; done
	@echo ""
	@echo "=== Alpine ==="
	@for go in $(RESOLVED_GO); do for llvm in $(RESOLVED_LLVM); do echo "  alpine-go$${go}-llvm$${llvm}"; done; done

# ---- Dynamic target generation ----
UBUNTU_TAGS   := $(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),ubuntu-22.04-go$(go)-llvm$(llvm)))
ALPINE_TAGS   := $(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),alpine-go$(go)-llvm$(llvm)))

# Used also for shorthand aliases
GO_SHORTS   := $(GO_VERSIONS)
GO_FULLS    := $(RESOLVED_GO)
LLVM_SHORTS := $(LLVM_VERSIONS)
LLVM_FULLS  := $(RESOLVED_LLVM)

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

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call BUILD_UBUNTU,$(go),$(llvm)))))

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

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call BUILD_ALPINE,$(go),$(llvm)))))

# ---- Shorthand aliases (Go only) ----
# Go major.minor (e.g. "1.26") is a prefix of the resolved version (e.g. "1.26.4"),
# so findstring works for mapping. LLVM short tags (e.g. "22.1") don't substring
# the resolved tag (e.g. "20260616"), so those must use the resolved tag directly.

define SHORT_UBUNTU
build-ubuntu-22.04-go$(1)-llvm$(2): build-ubuntu-22.04-go$(3)-llvm$(2)
endef

define SHORT_ALPINE
build-alpine-go$(1)-llvm$(2): build-alpine-go$(3)-llvm$(2)
endef

$(foreach gs,$(GO_SHORTS),\
  $(foreach gf,$(GO_FULLS),\
    $(if $(findstring $(gs),$(gf)),\
      $(foreach llvm,$(RESOLVED_LLVM),\
        $(eval $(call SHORT_UBUNTU,$(gs),$(llvm),$(gf)))\
        $(eval $(call SHORT_ALPINE,$(gs),$(llvm),$(gf)))\
      )\
    )\
  )\
)

# Ubuntu push targets
define PUSH_UBUNTU
push-ubuntu-22.04-go$(1)-llvm$(2): build-ubuntu-22.04-go$(1)-llvm$(2)
	docker push "$(REGISTRY)/$(IMAGE_NAME):ubuntu-22.04-go$(1)-llvm$(2)"
endef

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call PUSH_UBUNTU,$(go),$(llvm)))))

# Alpine push targets
define PUSH_ALPINE
push-alpine-go$(1)-llvm$(2): build-alpine-go$(1)-llvm$(2)
	docker push "$(REGISTRY)/$(IMAGE_NAME):alpine-go$(1)-llvm$(2)"
endef

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call PUSH_ALPINE,$(go),$(llvm)))))

# Ubuntu all-in-one
build-ubuntu: $(addprefix build-,$(UBUNTU_TAGS))
	@echo "All Ubuntu images done."

push-ubuntu: $(addprefix push-,$(UBUNTU_TAGS))
	@echo "All Ubuntu images pushed."

# Alpine all-in-one
build-alpine: $(addprefix build-,$(ALPINE_TAGS))
	@echo "All Alpine images done."

push-alpine: $(addprefix push-,$(ALPINE_TAGS))
	@echo "All Alpine images pushed."

# All
build-all: build-ubuntu build-alpine
	@echo "=== All images built ==="

push: push-ubuntu push-alpine
	@echo "=== All images pushed ==="

# ---- Clean ----
clean:
	@echo "Removing images..."
	@for tag in $(UBUNTU_TAGS) $(ALPINE_TAGS); do docker rmi "$(IMAGE_NAME):$$tag" 2>/dev/null || true; docker rmi "$(REGISTRY)/$(IMAGE_NAME):$$tag" 2>/dev/null || true; done
	@echo "Done."

.PHONY: help list build-all build-ubuntu build-alpine push push-ubuntu push-alpine clean
