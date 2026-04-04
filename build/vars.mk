#
# build/vars.mk — Project-level variables
#
# Override on the command line or in the environment:
#   registry=your.registry.example:5000   — prefix all images with this registry
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
        dgop-bin dms-shell-bin greetd-dms-greeter-git dsearch-bin \
        scenefx0.4 mangowm openbgpd  # scenefx0.4 must precede mangowm (runtime dep)

# Packages that must be installed into the build env after building so that
# subsequent packages can satisfy their runtime dependencies via makepkg.
# dgop-bin: provides 'dgop' required by dms-shell-bin
# scenefx0.4: provides 'scenefx0.4' required by mangowm
local_deps = dgop-bin scenefx0.4
subs  = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime \
        nvidia-container-toolkit zen-browser-bin zen-browser-avx2-bin \
        scenefx0.4 mangowm openbgpd  # scenefx0.4: AUR dep of mangowm; not in pacman repos

REPODIR ?= $(CURDIR)/repo

OPTIONS = (!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)

# Repo (nginx) image — the pacman repo served to clients
REPO_IMAGE_NAME ?= zachfi/aur
REPO_IMAGE_FULL  = $(if $(registry),$(registry)/$(REPO_IMAGE_NAME),$(REPO_IMAGE_NAME))

# Build image — Arch Linux + makepkg, used by CI and ci-docker
BUILD_IMAGE_NAME ?= zachfi/aur-build
BUILD_IMAGE_TAG  ?= latest
BUILD_IMAGE_FULL  = $(if $(registry),$(registry)/$(BUILD_IMAGE_NAME),$(BUILD_IMAGE_NAME))
