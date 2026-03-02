#
# build/vars.mk — Project-level variables
#
# Override on the command line or in the environment:
#   registry=reg.dist.svc.cluster.znet:5000   — prefix all images with this registry
#   archs=x86_64                               — target architectures
#
# Lowercase `registry` follows the same convention as zachfi/streamgo.
# When set, images are tagged as registry/name:tag and the local name:tag alias
# is also kept so local docker run commands work without the registry prefix.
#

PROJECT_NAME ?= aur

# Package list — keep in sync with build/woodpecker.jsonnet repoPkgs
archs ?= x86_64
pkgs  = nodemanager-bin k3s-bin gomplate-bin duo_unix zen-browser-avx2-bin \
        dms-shell-bin greetd-dms-greeter-git dgop-bin dsearch-bin claude-code
subs  = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime \
        nvidia-container-toolkit zen-browser-bin zen-browser-avx2-bin

REPODIR ?= $(CURDIR)/repo

OPTIONS = (!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)

# Repo (nginx) image — the pacman repo served to clients
REPO_IMAGE_NAME ?= zachfi/aur
REPO_IMAGE_FULL  = $(if $(registry),$(registry)/$(REPO_IMAGE_NAME),$(REPO_IMAGE_NAME))

# Build image — Arch Linux + makepkg, used by CI and ci-docker
BUILD_IMAGE_NAME ?= zachfi/aur-build
BUILD_IMAGE_TAG  ?= latest
BUILD_IMAGE_FULL  = $(if $(registry),$(registry)/$(BUILD_IMAGE_NAME),$(BUILD_IMAGE_NAME))
