#
# build/vars.mk — Project-level variables
#
# Package list (pkgs, local_deps, archs) lives in build/packages.libsonnet.
# build/packages.auto.mk is generated from it via: make woodpecker
#

PROJECT_NAME ?= aur
REGISTRY     ?= reg.dist.svc.cluster.znet:5000

# Auto-generated from build/packages.libsonnet — do not edit directly.
# Regenerate with: make woodpecker
include build/packages.auto.mk

REPODIR ?= $(CURDIR)/repo

OPTIONS = (!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)

# Repo (nginx) image — the pacman repo served to clients
REPO_IMAGE_NAME ?= zachfi/aur
REPO_IMAGE_FULL  = $(REGISTRY)/$(REPO_IMAGE_NAME)

# Build image — Arch Linux + makepkg, used by CI and ci-docker
BUILD_IMAGE_NAME ?= zachfi/aur-build
BUILD_IMAGE_TAG  ?= latest
BUILD_IMAGE_FULL  = $(REGISTRY)/$(BUILD_IMAGE_NAME)
