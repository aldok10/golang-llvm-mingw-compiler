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
LLVM_VERSIONS  ?= 22.1 21.1 20.1 19.1 18.1 17.0
REGISTRY           ?= ghcr.io/aldok10
IMAGE_NAME         ?= golang-llvm-mingw-compiler
DOCKER_HUB_REPO    ?= docker.io/akarendra835/llvm-mingw-golang

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
	@echo "  make push-docker-hub          Push all to Docker Hub ($(DOCKER_HUB_REPO))"
	@echo "  make push-docker-hub-ubuntu   Push Ubuntu images to Docker Hub"
	@echo "  make push-docker-hub-alpine   Push Alpine images to Docker Hub"
	@echo "  make buildx-docker-hub        Multi-arch build+push (amd64+arm64) to Docker Hub"
	@echo "  make buildx-docker-hub-ubuntu Multi-arch Ubuntu to Docker Hub"
	@echo "  make buildx-docker-hub-alpine Multi-arch Alpine to Docker Hub"
	@echo "  make list               List combinations"
	@echo "  make clean              Remove local images"
	@echo ""
	@echo "Registries:"
	@echo "  Default (GHCR): $(REGISTRY)/$(IMAGE_NAME)"
	@echo "  Docker Hub:     $(DOCKER_HUB_REPO)"
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

# ---- Docker Hub push targets ----
# Tags + pushes local images to Docker Hub without rebuilding.

define PUSH_DOCKER_HUB_UBUNTU
push-docker-hub-ubuntu-22.04-go$(1)-llvm$(2): build-ubuntu-22.04-go$(1)-llvm$(2)
	docker tag "$(IMAGE_NAME):ubuntu-22.04-go$(1)-llvm$(2)" "$(DOCKER_HUB_REPO):ubuntu-22.04-go$(1)-llvm$(2)"
	docker push "$(DOCKER_HUB_REPO):ubuntu-22.04-go$(1)-llvm$(2)"
endef

define PUSH_DOCKER_HUB_ALPINE
push-docker-hub-alpine-go$(1)-llvm$(2): build-alpine-go$(1)-llvm$(2)
	docker tag "$(IMAGE_NAME):alpine-go$(1)-llvm$(2)" "$(DOCKER_HUB_REPO):alpine-go$(1)-llvm$(2)"
	docker push "$(DOCKER_HUB_REPO):alpine-go$(1)-llvm$(2)"
endef

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call PUSH_DOCKER_HUB_UBUNTU,$(go),$(llvm)))))
$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call PUSH_DOCKER_HUB_ALPINE,$(go),$(llvm)))))

# ---- Multi-arch Docker Hub build+push (buildx) ----
# Builds for both linux/amd64 and linux/arm64, pushes directly to Docker Hub.
# Requires buildx with multi-arch driver (docker-container).
# Builder name: multiarch (create with: docker buildx create --name multiarch --driver docker-container --bootstrap)

BUILDX_BUILDER ?= multiarch

define BUILDX_DOCKER_HUB_UBUNTU
buildx-docker-hub-ubuntu-22.04-go$(1)-llvm$(2):
	@echo "=== [buildx] ubuntu-22.04 go$(1) llvm$(2) multi-arch ==="
	docker buildx build \
		--builder $(BUILDX_BUILDER) \
		--platform linux/amd64,linux/arm64 \
		--build-arg GO_VERSION="$(1)" \
		--build-arg LLVM_VERSION="$(2)" \
		-f Dockerfile.ubuntu \
		-t "$(DOCKER_HUB_REPO):ubuntu-22.04-go$(1)-llvm$(2)" \
		--push \
		.
endef

define BUILDX_DOCKER_HUB_ALPINE
buildx-docker-hub-alpine-go$(1)-llvm$(2):
	@echo "=== [buildx] alpine go$(1) llvm$(2) multi-arch ==="
	docker buildx build \
		--builder $(BUILDX_BUILDER) \
		--platform linux/amd64,linux/arm64 \
		--build-arg GO_VERSION="$(1)" \
		--build-arg LLVM_VERSION="$(2)" \
		-f Dockerfile.alpine \
		-t "$(DOCKER_HUB_REPO):alpine-go$(1)-llvm$(2)" \
		--push \
		.
endef

$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call BUILDX_DOCKER_HUB_UBUNTU,$(go),$(llvm)))))
$(foreach go,$(RESOLVED_GO),$(foreach llvm,$(RESOLVED_LLVM),$(eval $(call BUILDX_DOCKER_HUB_ALPINE,$(go),$(llvm)))))

# Ubuntu all-in-one
build-ubuntu: $(addprefix build-,$(UBUNTU_TAGS))
	@echo "All Ubuntu images done."

push-ubuntu: $(addprefix push-,$(UBUNTU_TAGS))
	@echo "All Ubuntu images pushed to $(REGISTRY)."

push-docker-hub-ubuntu: $(addprefix push-docker-hub-,$(UBUNTU_TAGS))
	@echo "All Ubuntu images pushed to $(DOCKER_HUB_REPO)."

# Alpine all-in-one
build-alpine: $(addprefix build-,$(ALPINE_TAGS))
	@echo "All Alpine images done."

push-alpine: $(addprefix push-,$(ALPINE_TAGS))
	@echo "All Alpine images pushed to $(REGISTRY)."

push-docker-hub-alpine: $(addprefix push-docker-hub-,$(ALPINE_TAGS))
	@echo "All Alpine images pushed to $(DOCKER_HUB_REPO)."

push-docker-hub: push-docker-hub-ubuntu push-docker-hub-alpine
	@echo "=== All images pushed to $(DOCKER_HUB_REPO) ==="

buildx-docker-hub-ubuntu: $(addprefix buildx-docker-hub-,$(UBUNTU_TAGS))
	@echo "=== All Ubuntu multi-arch images built+push to $(DOCKER_HUB_REPO) ==="

buildx-docker-hub-alpine: $(addprefix buildx-docker-hub-,$(ALPINE_TAGS))
	@echo "=== All Alpine multi-arch images built+push to $(DOCKER_HUB_REPO) ==="

buildx-docker-hub: buildx-docker-hub-ubuntu buildx-docker-hub-alpine
	@echo "=== All multi-arch images pushed to $(DOCKER_HUB_REPO) ==="

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

.PHONY: help list build-all build-ubuntu build-alpine push push-ubuntu push-alpine push-docker-hub push-docker-hub-ubuntu push-docker-hub-alpine buildx-docker-hub buildx-docker-hub-ubuntu buildx-docker-hub-alpine clean
