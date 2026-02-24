.PHONY: all clean drone repo ci ci-docker build-image

# Aligned with .drone.jsonnet repoPkgs/repoArchs
archs ?= x86_64
pkgs = nodemanager-bin k3s-bin gomplate-bin duo_unix zen-browser-avx2-bin dms-shell-bin greetd-dms-greeter-git dgop-bin dsearch-bin claude-code
subs = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime nvidia-container-toolkit zen-browser-bin zen-browser-avx2-bin

REPODIR ?= $(shell pwd)/repo
# Set REGISTRY for internal push, e.g. reg.dist.svc.cluster.znet:5000
REGISTRY ?=
IMAGE ?= zachfi/aur
FULL_IMAGE = $(if $(REGISTRY),$(REGISTRY)/$(IMAGE),$(IMAGE))

OPTIONS=(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)

clean:
	@rm -rf $(REPODIR)/*
	@rm -f */*.pkg.tar.zst

modules:
	@git submodule init
	@git submodule update --recursive --remote

cd: modules
	@for pkg in $(pkgs); do git add $$pkg; done
	@git ci -m 'Updates'
	@git push origin main

chown:
	@sudo chown -R makepkg $(REPODIR)/

.PHONY: packages-%
packages-%:
	@for pkg in $(pkgs); do pushd $$pkg; CARCH=$* OPTIONS=$(OPTIONS) makepkg -c; popd; done

.PHONY: repo-%
repo-%:
	@mkdir $(REPODIR)/$*
	@$(MAKE) packages-$*
	@cp */*$*.pkg.tar.zst $(REPODIR)/$*
	@find $(REPODIR)/$* -name "*-debug-*" -exec rm {} \;
	@repo-add $(REPODIR)/$*/custom.db.tar.gz $(REPODIR)/$*/*pkg.tar.zst

# CI-style build: one image with repo contents (matches Drone pipeline)
.PHONY: docker
docker: repo
	@docker build -f Dockerfile -t $(FULL_IMAGE):latest $(REPODIR)

# Legacy per-arch builds (for multi-arch images)
.PHONY: docker-%
docker-%:
	@docker pull nginx:alpine
	@docker build --progress=plain --build-arg arch=$* -t $(FULL_IMAGE):$* .

.PHONY: repo
repo: modules clean
	@ls -ld $(REPODIR) || mkdir -p $(REPODIR)
	@for r in $(archs); do $(MAKE) repo-$$r; done

.PHONY: image
image:
	@for r in $(archs); do $(MAKE) docker-$$r; done

# Push CI-style image (single :latest)
publish: docker
	@docker push $(FULL_IMAGE):latest

# Legacy per-arch push
publish-multiarch: image
	@for r in $(archs); do docker push $(FULL_IMAGE):$$r; done

# Full CI-equivalent pipeline: modules -> repo -> docker -> publish
ci: modules
	@$(MAKE) publish

# Build the Arch-based container with all AUR build deps (greetd, quickshell, etc.)
BUILD_IMAGE ?= zachfi/aur-build
build-image:
	@docker build -f Dockerfile.build -t $(BUILD_IMAGE):latest .

# Run CI inside the build container (no local Arch/greetd/quickshell needed)
DOCKER_GID ?= $(shell stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 999)
ci-docker: build-image
	@docker run --rm -it \
		-v "$(shell pwd):/workspace" \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--group-add $(DOCKER_GID) \
		-e REGISTRY="$(REGISTRY)" \
		-e IMAGE="$(IMAGE)" \
		-w /workspace \
		$(BUILD_IMAGE):latest ci

.PHONY: drone drone-signature
drone:
	@drone jsonnet --stream --format
	@drone lint --trusted

drone-signature:
ifndef DRONE_TOKEN
	$(error DRONE_TOKEN is not set, visit https://drone.zach.fi/account)
endif
	@DRONE_SERVER=https://drone.zach.fi drone sign --save zachfi/aur .drone.yml
