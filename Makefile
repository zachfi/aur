.PHONY: all clean drone repo

archs = x86_64 armv7h aarch64
pkgs = nodemanager-bin
subs = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime nvidia-container-toolkit

REPODIR ?= $(shell pwd)/repo

clean:
	@rm -rf $(REPODIR)/*
	@rm -f */*.pkg.tar.zst

docker-%:

.PHONY: packages-%
packages-%:
	@for pkg in $(pkgs); do pushd $$pkg; CARCH=$* makepkg -c; popd; done

#$(archs):
#	@for pkg in $(pkgs); do pushd $$pkg; makepkg -c; popd;  done

.PHONY: repo-%
repo-%:
	@mkdir $(REPODIR)/$*
	@$(MAKE) packages-$*
	@cp */*$*.pkg.tar.zst repo/$*
	@find $(REPODIR)/$* -name "*-debug-*" -exec rm {} \;
	@repo-add $(REPODIR)/$*/custom.db.tar.gz $(REPODIR)/$*/*pkg.tar.zst

.PHONY: docker-%
docker-%:
	@docker build --build-arg arch=$* -t zachfi/aur:$* .

.PHONY: repo
repo: clean
	@mkdir $(REPODIR)/
	@for r in $(archs); do $(MAKE) repo-$$r; done

.PHONY: image
image:
	@for r in $(archs); do $(MAKE) docker-$$r; done

publish:
	@for r in $(archs); do docker push zachfi/aur:$$r; done

.PHONY: drone
drone:
	@drone jsonnet --format
	@drone lint
