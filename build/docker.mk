#
# build/docker.mk — Docker targets for the build image and repo image
#
# Expects build/vars.mk for: BUILD_IMAGE_NAME, BUILD_IMAGE_TAG, BUILD_IMAGE_FULL,
#                             REPO_IMAGE_NAME, REPO_IMAGE_FULL, REPODIR
#
# Pass registry= on the command line to tag and push to a registry:
#   make build-image registry=reg.dist.svc.cluster.znet:5000
#   make push-build-image registry=reg.dist.svc.cluster.znet:5000
#

DOCKER_GID ?= $(shell stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 999)

# ---------------------------------------------------------------------------
# Build image (Dockerfile.build) — Arch Linux + makepkg environment
# ---------------------------------------------------------------------------

.PHONY: build-image
build-image:
	@echo "=== $(PROJECT_NAME) === [ build-image      ]: building $(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG)..."
	@docker build -f Dockerfile.build -t $(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG) .
	@if [ -n "$(registry)" ]; then \
		docker tag $(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG) $(BUILD_IMAGE_NAME):$(BUILD_IMAGE_TAG); \
	fi

.PHONY: push-build-image
push-build-image:
	@echo "=== $(PROJECT_NAME) === [ push-build-image ]: pushing $(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG)..."
	@docker push $(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG)

# Build and push in one step (mirrors streamgo docker-snapshot pattern)
.PHONY: build-image-push
build-image-push: build-image push-build-image

# ---------------------------------------------------------------------------
# Run the full CI pipeline inside the build container (no local Arch needed).
# Mounts workspace + docker socket.  Translates to: make ci inside container.
# ---------------------------------------------------------------------------

.PHONY: ci-docker
ci-docker: build-image
	@docker run --rm -it \
		-v "$(CURDIR):/workspace" \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--group-add $(DOCKER_GID) \
		-e registry="$(registry)" \
		-e IMAGE="$(REPO_IMAGE_NAME)" \
		-w /workspace \
		$(BUILD_IMAGE_FULL):$(BUILD_IMAGE_TAG) ci

# ---------------------------------------------------------------------------
# Repo (nginx) image (Dockerfile) — static pacman repo served over HTTP
# ---------------------------------------------------------------------------

.PHONY: docker
docker: repo
	@echo "=== $(PROJECT_NAME) === [ docker           ]: building $(REPO_IMAGE_FULL):latest..."
	@docker build -f Dockerfile -t $(REPO_IMAGE_FULL):latest $(REPODIR)

.PHONY: publish
publish: docker
	@echo "=== $(PROJECT_NAME) === [ publish          ]: pushing $(REPO_IMAGE_FULL):latest..."
	@docker push $(REPO_IMAGE_FULL):latest
