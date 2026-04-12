// build/woodpecker.jsonnet — Woodpecker CI pipeline for the AUR package repo
//
// Generate .woodpecker.yml via:  make ci-pipeline
//
// To add a package: append to repoPkgs in packages.libsonnet. The build, copy,
// and repo-add steps are derived automatically from that list.

local registry = 'reg.dist.svc.cluster.znet:5000';
local buildImage = registry + '/zachfi/aur-build:latest';
local repoImage = registry + '/zachfi/aur';

local p = import 'packages.libsonnet';
local repoArchs = p.archs;
local localDeps = p.localDeps;
local repoPkgs = p.pkgs;

local options = '(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)';

// repo/ lives inside the shared workspace — no separate volume needed.
local repoDir = 'repo';

// ---------------------------------------------------------------------------
// Volume definitions (Woodpecker 3.x string format: host:container)
// ---------------------------------------------------------------------------
local dockerVol = ['/var/run/docker.sock:/var/run/docker.sock'];

// ---------------------------------------------------------------------------
// Step helpers
// ---------------------------------------------------------------------------
local step(name, commands, volumes=null, environment=null, when=null) = (
  {
    name: name,
    image: buildImage,
    pull: true,
    commands: commands,
  }
  + (if volumes != null then { volumes: volumes } else {})
  + (if environment != null then { environment: environment } else {})
  + (if when != null then { when: when } else {})
);

local pkgEnv(arch) = { CARCH: arch, OPTIONS: options };

// ---------------------------------------------------------------------------
// Pipeline steps
// ---------------------------------------------------------------------------
local initRepo(arch) = step(
  name='init-repo-' + arch,
  commands=[
    'mkdir -p %(repo)s/%(arch)s' % { repo: repoDir, arch: arch },
    'git submodule init',
    'git submodule update',
  ],
);

local buildPkg(pkg, arch) = step(
  name='build-pkg-' + pkg + '-' + arch,
  commands=['cd ' + pkg + ' && makepkg -c'],
  environment=pkgEnv(arch),
);

local installLocalDep(pkg, arch) = step(
  name='install-dep-' + pkg + '-' + arch,
  commands=['sudo pacman -U --noconfirm $(ls ' + pkg + "/*.pkg.tar.zst | grep -v -- '-debug-')"],
  environment=pkgEnv(arch),
);

local mkRepo(arch) = step(
  name='make-repo-' + arch,
  commands=
  ['cp %(pkg)s/*%(arch)s*.pkg.tar.zst %(repo)s/%(arch)s' % { pkg: pkg, arch: arch, repo: repoDir } for pkg in repoPkgs]
  + [
    "find . -maxdepth 2 -name '*-any.pkg.tar.zst' -exec cp {} %(repo)s/%(arch)s +" % { repo: repoDir, arch: arch },
    "find %(repo)s/%(arch)s -name '*-debug-*' -delete" % { repo: repoDir, arch: arch },
    'repo-add %(repo)s/%(a)s/custom.db.tar.gz %(repo)s/%(a)s/*pkg.tar.zst' % { repo: repoDir, a: arch },
  ],
  environment=pkgEnv(arch),
);

local buildDockerImage() = step(
  name='build-image',
  commands=['sudo docker build -t ' + repoImage + ' -f Dockerfile ' + repoDir],
  volumes=dockerVol,
);

local publishDockerImage() = step(
  name='publish-image',
  commands=['sudo docker push ' + repoImage],
  volumes=dockerVol,
  when={ event: 'push', branch: 'main' },
);

// ---------------------------------------------------------------------------
// Assemble pipeline
// ---------------------------------------------------------------------------
local buildSteps(arch) = std.flatMap(
  function(pkg)
    [buildPkg(pkg, arch)] +
    (if std.member(localDeps, pkg) then [installLocalDep(pkg, arch)] else []),
  repoPkgs
);

local steps =
  [initRepo(arch) for arch in repoArchs]
  + std.flatMap(buildSteps, repoArchs)
  + [mkRepo(arch) for arch in repoArchs]
  + [buildDockerImage(), publishDockerImage()];

std.manifestYamlDoc({
  when: { event: 'push', branch: 'main' },
  steps: steps,
})
