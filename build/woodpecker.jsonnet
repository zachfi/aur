// build/woodpecker.jsonnet — Woodpecker CI pipeline for the AUR package repo
//
// Generate .woodpecker.yml via:  make ci-pipeline
//
// To add a package: append to repoPkgs. The build, copy, and repo-add steps
// are derived automatically from that list.

local registry = 'reg.dist.svc.cluster.znet:5000';
local buildImage = registry + '/zachfi/aur-build-image:latest';
local repoImage = registry + '/zachfi/aur';

local repoArchs = ['x86_64'];

local repoPkgs = [
  'nodemanager-bin',
  'k3s-bin',
  'gomplate-bin',
  'duo_unix',
  'zen-browser-avx2-bin',
  'dms-shell-bin',
  'greetd-dms-greeter-git',
  'dgop-bin',
  'dsearch-bin',
  'claude-code',
];

local options = '(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)';

// ---------------------------------------------------------------------------
// Shared volume definitions (referenced by name in each step)
// ---------------------------------------------------------------------------
local repoVol = [{ name: 'repo', path: '/repo' }];
local dockerVol = [{ name: 'dockersock', path: '/var/run/docker.sock' }];

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
    'sudo mkdir -p /repo/' + arch,
    'sudo chown -R makepkg /repo',
    'sudo chown -R makepkg "$CI_WORKSPACE"',
    'git submodule init',
    'git submodule update',
  ],
  volumes=repoVol,
);

local buildPkg(pkg, arch) = step(
  name='build-pkg-' + pkg + '-' + arch,
  commands=['cd ' + pkg + ' && makepkg -c'],
  volumes=repoVol,
  environment=pkgEnv(arch),
);

local mkRepo(arch) = step(
  name='make-repo-' + arch,
  commands=
    ['cp %(pkg)s/*%(arch)s*.pkg.tar.zst /repo/%(arch)s' % { pkg: pkg, arch: arch } for pkg in repoPkgs]
    + [
      "find /repo/%(arch)s -name '*-debug-*' -exec rm {} \\;" % { arch: arch },
      'repo-add /repo/%(a)s/custom.db.tar.gz /repo/%(a)s/*pkg.tar.zst' % { a: arch },
    ],
  volumes=repoVol,
  environment=pkgEnv(arch),
);

local buildDockerImage() = step(
  name='build-image',
  commands=['sudo docker build -t ' + repoImage + ' -f Dockerfile /repo'],
  volumes=repoVol + dockerVol,
);

local publishDockerImage() = step(
  name='publish-image',
  commands=['sudo docker push ' + repoImage],
  volumes=dockerVol,
  when=[{ event: 'push', branch: 'main' }],
);

// ---------------------------------------------------------------------------
// Assemble pipeline
// ---------------------------------------------------------------------------
local steps =
  [initRepo(arch) for arch in repoArchs]
  + [buildPkg(pkg, arch) for arch in repoArchs for pkg in repoPkgs]
  + [mkRepo(arch) for arch in repoArchs]
  + [buildDockerImage(), publishDockerImage()];

local volumes = [
  { name: 'repo', temp: {} },
  { name: 'dockersock', host: { path: '/var/run/docker.sock' } },
];

std.manifestYamlDoc({
  when: [{ event: 'push', branch: 'main' }],
  steps: steps,
  volumes: volumes,
})
