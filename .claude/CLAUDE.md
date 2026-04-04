# AUR Package Repository

Personal Arch Linux package repository built from AUR PKGBUILDs and custom packages.
Builds packages into a pacman repo and serves it as a Docker image via nginx.

Registry: `reg.dist.svc.cluster.znet:5000` (hardcoded; single-user repo).

## Structure

```
Makefile              — thin wrapper; includes build/*.mk
Dockerfile            — nginx:alpine image serving the built repo/
Dockerfile.build      — Arch Linux image for running makepkg (the build environment)
build/
  vars.mk             — shared variables (image names, REGISTRY); includes packages.auto.mk
  packages.libsonnet  — single source of truth: pkgs, localDeps, archs
  packages.jsonnet    — generates build/packages.auto.mk from packages.libsonnet
  packages.auto.mk    — generated; do not edit (commit alongside .woodpecker.yml)
  woodpecker.jsonnet  — Woodpecker CI pipeline; imports packages.libsonnet
  repo.mk             — modules, clean, clean-modules, distclean, packages-%, repo-%, repo
  docker.mk           — build-image, push-build-image, docker, publish, ci-docker
  ci.mk               — ci-pipeline + packages-mk: jsonnet → .woodpecker.yml + packages.auto.mk
.woodpecker.yml       — generated from woodpecker.jsonnet; commit this file
```

Each package is a subdirectory (most are git submodules from AUR).

## Adding a Package

1. Add the git submodule: `git submodule add <aur-url> <pkgname>`
2. Append `<pkgname>` to `pkgs` in `build/packages.libsonnet` (respecting dep order)
3. If it must be installed before a later package can build, add it to `localDeps` too
4. Run: `make woodpecker`
5. Commit `build/packages.libsonnet`, `build/packages.auto.mk`, and `.woodpecker.yml`

## Local Build Workflow (no CI required)

```sh
# Build the Arch-based build container (once, or when Dockerfile.build changes)
make build-image
make push-build-image

# Run the full pipeline inside the build container (mounts workspace + docker socket)
make ci-docker

# Individual steps
make modules          # git submodule init + update
make repo             # build all packages and assemble repo/ for all archs
make repo-x86_64      # single arch
make docker           # docker build -f Dockerfile repo/  (after make repo)
make publish          # docker + push repo image

# Regenerate .woodpecker.yml and build/packages.auto.mk from jsonnet
make woodpecker

# Clean up after a build (deinits submodules, leaving git status clean)
make distclean
```

`make ci-docker` runs `docker run ... $(BUILD_IMAGE) ci` which invokes `make ci`
inside the container via `ENTRYPOINT ["make"]` in Dockerfile.build.

## CI — Woodpecker

Pipeline defined in `.woodpecker.yml`, generated from `build/woodpecker.jsonnet`
(which imports `build/packages.libsonnet`) via `make woodpecker`.

A pre-commit hook automatically regenerates both files when any jsonnet source is staged.

Future: Woodpecker pipeline builds new repo image on push to main, then triggers
a rollout-restart of the nginx workload on Kubernetes.

## Dependency Submodules

Some packages are included solely as dependencies of other packages because they
are not available in the official pacman repos.  When adding or removing these,
keep both the submodule and `localDeps` in `build/packages.libsonnet` in sync.

| Submodule    | Required by | Reason not in pacman |
|--------------|-------------|----------------------|
| `scenefx0.4` | `mangowm`   | AUR only; provides `scenefx0.4` runtime lib |

`wlroots0.19` (also required by `mangowm` and `scenefx0.4`) **is** available in
the `extra` repo and is installed in `Dockerfile.build` via pacman rather than
as a submodule.  If either package is dropped or these libs land in the official
repos, remove the corresponding submodule and pacman entry.

## ci-docker sudo setup

`ci-docker` passes `--user $(id -u):$(id -g)` so the host UID can write to the
mounted workspace.  For `sudo` to work inside the container with an arbitrary UID:
- `Dockerfile.build` makes `/etc/passwd` world-writable (0666) via `chmod` AFTER `useradd`
- `entrypoint.sh` registers the runtime UID in `/etc/passwd` if not present
- `/etc/pam.d/sudo` uses `pam_permit.so` so shadow-less users pass PAM account checks
- sudoers: `ALL ALL=(ALL:ALL) NOPASSWD: ALL`
