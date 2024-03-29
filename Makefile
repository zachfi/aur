.PHONY: all clean drone repo

archs = x86_64 armv7h aarch64
pkgs = nodemanager-bin
subs = duo_unix gomplate-bin k3s-bin libnvidia-container nvidia-container-runtime nvidia-container-toolkit

clean:
	@rm -rf repo/
	@rm -f */*.pkg.tar.zst

docker-%:

.PHONY: packages-%
packages-%:
	@for pkg in $(pkgs); do pushd $$pkg; CARCH=$* makepkg -c; popd; done

#$(archs):
#	@for pkg in $(pkgs); do pushd $$pkg; makepkg -c; popd;  done

.PHONY: repo-%
repo-%:
	@mkdir repo/$*
	@$(MAKE) packages-$*
	@cp */*$*.pkg.tar.zst repo/$*
	@find repo/$* -name "*-debug-*" -exec rm {} \;
	@repo-add repo/$*/custom.db.tar.gz repo/$*/*pkg.tar.zst

.PHONY: docker-%
docker-%:
	@docker build --build-arg arch=$* -t zachfi/aur:$* .

.PHONY: repo
repo: clean
	@mkdir repo/
	@for r in $(archs); do $(MAKE) repo-$$r; done

.PHONY: image
image:
	@for r in $(archs); do $(MAKE) docker-$$r; done

publish:
	@for r in $(archs); do docker push zachfi/aur:$$r; done

drone:
	@drone jsonnet --format
	@drone lint
