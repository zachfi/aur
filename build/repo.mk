#
# build/repo.mk — AUR package building and pacman repo assembly
#
# Expects build/vars.mk for: archs, pkgs, REPODIR, OPTIONS
#

.PHONY: clean modules chown repo

clean:
	@rm -rf $(REPODIR)/*
	@rm -f */*.pkg.tar.zst

modules:
	@git submodule init
	@git submodule update --recursive --remote

chown:
	@sudo chown -R makepkg $(REPODIR)/

# Build all packages for a given arch.  Runs makepkg in a subshell per package
# so directory state is isolated (no pushd/popd required).
# After building a package listed in local_deps, installs it into the build
# environment so that subsequent packages can satisfy their runtime deps.
.PHONY: packages-%
packages-%:
	@for pkg in $(pkgs); do \
		(cd $$pkg && CARCH=$* OPTIONS=$(OPTIONS) makepkg -c) || exit 1; \
		for dep in $(local_deps); do \
			if [ "$$pkg" = "$$dep" ]; then \
				sudo pacman -U --noconfirm $$(ls $$pkg/*.pkg.tar.zst | grep -v -- '-debug-'); \
			fi; \
		done; \
	done

# Assemble the pacman repo for a single arch.
.PHONY: repo-%
repo-%:
	@mkdir -p $(REPODIR)/$*
	@$(MAKE) packages-$*
	@cp */*$*.pkg.tar.zst $(REPODIR)/$*
	@find $(REPODIR)/$* -name "*-debug-*" -exec rm {} \;
	@repo-add $(REPODIR)/$*/custom.db.tar.gz $(REPODIR)/$*/*pkg.tar.zst

# Build packages and assemble the repo for all target architectures.
repo: modules clean
	@ls -ld $(REPODIR) 2>/dev/null || mkdir -p $(REPODIR)
	@for r in $(archs); do $(MAKE) repo-$$r; done
