# Go + llvm-mingw Cross-Compiler Docker Images

Multi-version Docker images for cross-compiling Go projects to Windows using the [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) toolchain.

Supports **Ubuntu 22.04** and **Alpine Linux** bases with configurable Go and LLVM versions.

## Quick Start

```bash
# Build all combinations (Go 1.24, 1.25, 1.26 x LLVM 22.1, 21.1)
make build-all

# List available images
make list

# Build a specific image (major.minor shorthand)
make build-ubuntu-22.04-go1.26-llvm22.1

# Build all Ubuntu images
make build-ubuntu

# Build all Alpine images
make build-alpine
```

## How It Works

Both `GO_VERSIONS` and `LLVM_VERSIONS` accept **major.minor** format. The latest patch version is automatically resolved from upstream at build time:

| Variable | Input | Resolved |
|----------|-------|----------|
| `GO_VERSIONS=1.26` | `1.26` | `1.26.4` (latest from go.dev) |
| `LLVM_VERSIONS=22.1` | `22.1` | `20260616` (latest GitHub release tag) |

Resolution scripts:

- `scripts/resolve-go-versions.py` — fetches `go.dev/dl/`, finds highest patch per minor
- `scripts/resolve-llvm-versions.py` — fetches GitHub API, maps LLVM version to release tag

## Build

### All Images (Default Versions)

```bash
make build-all
```

This builds 12 images (3 Go versions x 2 LLVM versions x 2 base images) with auto-resolved patches.

### Custom Versions

```bash
# Single Go version, single LLVM version
make build-all GO_VERSIONS="1.26" LLVM_VERSIONS="22.1"

# Multiple versions
make build-all GO_VERSIONS="1.25 1.26" LLVM_VERSIONS="21.1 22.1"

# Specific base only
make build-ubuntu GO_VERSIONS="1.26" LLVM_VERSIONS="22.1"
make build-alpine GO_VERSIONS="1.26" LLVM_VERSIONS="22.1"
```

### Single Image

```bash
# By major.minor (auto-resolved)
make build-ubuntu-22.04-go1.26-llvm20260616

# By full resolved version
make build-alpine-go1.26.4-llvm20260616
```

### Matrix

The build matrix combines every Go version with every LLVM version for both base images:

| Base | Go | LLVM | Tag |
|------|----|------|-----|
| Ubuntu 22.04 | 1.26.4 | 20260616 | `ubuntu-22.04-go1.26.4-llvm20260616` |
| Ubuntu 22.04 | 1.25.11 | 20260616 | `ubuntu-22.04-go1.25.11-llvm20260616` |
| Ubuntu 22.04 | 1.24.13 | 20260616 | `ubuntu-22.04-go1.24.13-llvm20260616` |
| Ubuntu 22.04 | 1.26.4 | 20251216 | `ubuntu-22.04-go1.26.4-llvm20251216` |
| ... | ... | ... | ... |
| Alpine 3.20 | 1.26.4 | 20251216 | `alpine-go1.26.4-llvm20251216` |

Default: **12 images** (3 Go x 2 LLVM x 2 bases).

## Push to GitHub Container Registry

### Prerequisites

1. A [GitHub token](https://github.com/settings/tokens) with `write:packages` scope
2. Login to `ghcr.io`:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin
```

### Push All Images

```bash
make push
```

### Push Specific Base

```bash
make push-ubuntu
make push-alpine
```

### Tag Naming

Images are dual-tagged:

- `golang-llvm-mingw-compiler:ubuntu-22.04-go1.26.4-llvm20260616`
- `ghcr.io/aldok10/golang-llvm-mingw-compiler:ubuntu-22.04-go1.26.4-llvm20260616`

### Custom Registry

Override `REGISTRY` and `IMAGE_NAME`:

```bash
make push REGISTRY=docker.io/username IMAGE_NAME=my-cross-compiler
```

Or set in `.env`:

```
REGISTRY=docker.io/username
IMAGE_NAME=my-cross-compiler
```

## Configuration

### `.env` (local, gitignored)

```
# major.minor only (latest patch auto-resolved)
GO_VERSIONS=1.24 1.25 1.26
LLVM_VERSIONS=22.1 21.1

REGISTRY=ghcr.io/aldok10
IMAGE_NAME=golang-llvm-mingw-compiler
```

Copy `.env.example` to `.env` and edit:

```bash
cp .env.example .env
```

### Override via Environment

```bash
GO_VERSIONS="1.26" LLVM_VERSIONS="22.1" make build-all
```

## Dockerfiles

### Ubuntu (`Dockerfile.ubuntu`)

- Base: `ubuntu:22.04`
- Installs Go from `go.dev/dl/`
- Downloads llvm-mingw msvcrt-ubuntu-22.04 tarball from GitHub releases
- Binaries run natively (glibc-linked)

### Alpine (`Dockerfile.alpine`)

- Base: `alpine:3.20`
- Installs Go from `go.dev/dl/`
- Downloads the same llvm-mingw tarball
- Uses `gcompat` for glibc ABI compatibility
- Binaries are glibc-linked but run via gcompat on musl

### Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `GO_VERSION` | (required) | Go version, e.g. `1.26.4` |
| `LLVM_VERSION` | (required) | llvm-mingw release tag, e.g. `20260616` |
| `TARGETARCH` | `amd64` | Architecture (`amd64`, `arm64`) |

## Usage Example

```dockerfile
FROM ghcr.io/aldok10/golang-llvm-mingw-compiler:ubuntu-22.04-go1.26.4-llvm20260616 AS build

# Cross-compile for Windows
WORKDIR /src
COPY . .
RUN GOOS=windows GOARCH=amd64 CGO_ENABLED=1 \
    CC=x86_64-w64-mingw32-clang \
    go build -o output/app.exe .
```

## Automated Version Checks

A GitHub Actions workflow (`.github/workflows/version-check.yml`) runs daily at 06:00 UTC:

1. Checks latest Go versions from `go.dev`
2. Checks latest llvm-mingw releases from GitHub API
3. Creates a PR if new versions are found
4. Can optionally build and push updated images

### Manual Trigger

```bash
gh workflow run version-check.yml -f push_images=true
```

## Makefile Reference

| Target | Description |
|--------|-------------|
| `make help` | Show help (default) |
| `make build-all` | Build all combinations |
| `make build-ubuntu` | Build all Ubuntu images |
| `make build-alpine` | Build all Alpine images |
| `make push` | Push all images to registry |
| `make push-ubuntu` | Push Ubuntu images |
| `make push-alpine` | Push Alpine images |
| `make list` | List resolved versions and tags |
| `make clean` | Remove local images |
