.PHONY: all clean drone repo

archs = x86_64 armv7h aarch64
pkgs = nodemanager-bin
subs = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime nvidia-container-toolkit

REPODIR ?= $(shell pwd)/repo

OPTIONS=(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)

clean:
	@rm -rf $(REPODIR)/*
	@rm -f */*.pkg.tar.zst

modules:
	git submodule init
	git submodule update

chown:
	@sudo chown -R makepkg $(REPODIR)/

docker-%:

.PHONY: packages-%
packages-%:
	@for pkg in $(pkgs); do pushd $$pkg; CARCH=$* OPTIONS=$(OPTIONS) makepkg -c; popd; done

#$(archs):
#	@for pkg in $(pkgs); do pushd $$pkg; makepkg -c; popd;  done

.PHONY: repo-%
repo-%:
	@mkdir $(REPODIR)/$*
	@$(MAKE) packages-$*
	@cp */*$*.pkg.tar.zst $(REPODIR)/$*
	@find $(REPODIR)/$* -name "*-debug-*" -exec rm {} \;
	@repo-add $(REPODIR)/$*/custom.db.tar.gz $(REPODIR)/$*/*pkg.tar.zst

.PHONY: docker-%
docker-%:
	@docker build --build-arg arch=$* -t zachfi/aur:$* .

.PHONY: repo
repo: clean
	@ls -ld $(REPODIR) || mkdir $(REPODIR)/
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
