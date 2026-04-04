#
# build/ci.mk — CI pipeline generation
#
# make ci-pipeline   Render .woodpecker.yml from build/woodpecker.jsonnet
#
# jsonnet runs inside a throwaway alpine container so nothing needs to be
# installed on the host.  The -S (string output) flag lets jsonnet emit the
# YAML directly from std.manifestYamlDoc without requiring jq.
#
# Override variables if needed:
#   CI_CONFIG         — output file           (default: .woodpecker.yml)
#   CI_JSONNET_SOURCE — jsonnet source file   (default: build/woodpecker.jsonnet)
#   JSONNET_IMAGE     — image with jsonnet    (default: alpine:latest)
#

CI_CONFIG           ?= .woodpecker.yml
CI_JSONNET_SOURCE   ?= build/woodpecker.jsonnet
PACKAGES_JSONNET    ?= build/packages.jsonnet
PACKAGES_MK         ?= build/packages.auto.mk
JSONNET_IMAGE       ?= alpine:latest

.PHONY: ci-pipeline
ci-pipeline:
	@echo "=== $(PROJECT_NAME) === [ ci-pipeline      ]: rendering $(CI_CONFIG) from $(CI_JSONNET_SOURCE)..."
	@docker run --rm \
		-v "$(abspath .):/src:ro" \
		-w /src \
		$(JSONNET_IMAGE) \
		sh -c 'apk add -q --no-cache jsonnet && jsonnet -S $(CI_JSONNET_SOURCE)' \
		> $(CI_CONFIG)
	@echo "=== $(PROJECT_NAME) === [ ci-pipeline      ]: wrote $(CI_CONFIG)"

# Regenerate build/packages.auto.mk from build/packages.libsonnet.
# Included by build/vars.mk; commit alongside .woodpecker.yml after any
# package list change.
.PHONY: packages-mk
packages-mk:
	@echo "=== $(PROJECT_NAME) === [ packages-mk      ]: rendering $(PACKAGES_MK) from $(PACKAGES_JSONNET)..."
	@docker run --rm \
		-v "$(abspath .):/src:ro" \
		-w /src \
		$(JSONNET_IMAGE) \
		sh -c 'apk add -q --no-cache jsonnet && jsonnet -S $(PACKAGES_JSONNET)' \
		> $(PACKAGES_MK)
	@echo "=== $(PROJECT_NAME) === [ packages-mk      ]: wrote $(PACKAGES_MK)"
