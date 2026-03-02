SHELL := /bin/bash

include build/vars.mk
include build/repo.mk
include build/docker.mk
include build/ci.mk

.PHONY: all ci cd woodpecker

# Full local pipeline: build packages, assemble repo, build+push repo image
ci: modules
	@$(MAKE) publish

# Update submodules, stage, commit, and push
cd: modules
	@for pkg in $(pkgs); do git add $$pkg; done
	@git ci -m 'Updates'
	@git push origin main

# Render .woodpecker.yml from jsonnet (alias for ci-pipeline)
woodpecker: ci-pipeline
