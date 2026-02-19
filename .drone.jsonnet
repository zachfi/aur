local repoArchs = ['x86_64'];
local repoPkgs = [
  'nodemanager-bin',
  'k3s-bin',
  'gomplate-bin',
  'duo_unix',
  // 'grafana-alloy',
  // 'zen-browser-bin',
  'zen-browser-avx2-bin',
  'dms-shell-bin',
  // 'walker-bin'
];
local image = 'reg.dist.svc.cluster.znet:5000/zachfi/aur-build-image:latest';
local registry = 'reg.dist.svc.cluster.znet:5000';
local cacheBase = '/repo';

local pipeline(name) = {
  kind: 'pipeline',
  name: name,
  steps: [],
  depends_on: [],
  volumes: [
    { name: 'cache', temp: {} },
    { name: 'dockersock', host: { path: '/var/run/docker.sock' } },
  ],
  trigger: {
    branch: ['main'],
    event: ['push'],
  },
};

local step(name) = {
  name: name,
  image: image,
  // pull: 'always',
};

local initRepo(arch) = {
  local dir = '%s/%s' % [cacheBase, arch],

  name: 'init-repo-%s' % arch,
  image: image,
  commands: [
    'sudo mkdir -p /repo/%s' % arch,
    'sudo chown -R makepkg /repo',
    'sudo chown -R makepkg /drone',
    'git submodule init',
    'git submodule update',
  ],
  volumes+: [
    { name: 'cache', path: cacheBase },
  ],
};

local buildPkg(pkg, arch) = {
  local dir = '%s/%s' % [cacheBase, arch],

  name: 'build-pkg-%s-%s' % [pkg, arch],
  image: image,
  environment: {
    CARCH: arch,
    OPTIONS: '(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)',
  },
  commands: [
    'cd %s' % pkg,
    'makepkg -c',
  ],
  volumes+: [
    { name: 'cache', path: cacheBase },
  ],
};

local mkRepo(arch) = {
  local dir = '%s/%s' % [cacheBase, arch],

  name: 'make-repo-%s' % arch,
  image: image,
  environment: {
    CARCH: arch,
    OPTIONS: '(!strip docs libtool staticlibs emptydirs !zipman !purge !debug !lto !autodeps)',
  },
  commands:
    [
      'cp %s/*%s*.pkg.tar.zst %s' % [pkg, arch, dir]
      for pkg in repoPkgs
    ]
    + [
      'rm %s/*-debug-*' % dir,
      'repo-add %(dir)s/custom.db.tar.gz %(dir)s/*pkg.tar.zst' % { dir: dir },
    ],
  volumes+: [
    { name: 'cache', path: cacheBase },
  ],
};

local buildImage() = {
  name: 'build-image',
  image: image,
  commands:
    [
      'sudo docker build -t %(reg)s/zachfi/aur -f Dockerfile %(dir)s' % { dir: cacheBase, reg: registry },
    ],
  volumes+: [
    { name: 'cache', path: cacheBase },
    { name: 'dockersock', path: '/var/run/docker.sock' },
  ],
};

local publishImage() = {
  name: 'publish-image',
  image: image,
  commands:
    [
      // 'echo $DOCKER_PASSWORD | sudo docker login --username $DOCKER_USERNAME --password-stdin',
      'sudo docker push %s/zachfi/aur' % registry,
    ],
  volumes+: [
    { name: 'dockersock', path: '/var/run/docker.sock' },
  ],
  when: { branch: ['main'] },
  environment: {
    DOCKER_USERNAME: { from_secret: 'DOCKER_USERNAME' },
    DOCKER_PASSWORD: { from_secret: 'DOCKER_PASSWORD' },
  },
};

[
  (
    pipeline('ci') {
      steps:
        [
          initRepo(arch)
          for arch in repoArchs
        ]
        + [
          buildPkg(pkg, arch)
          for pkg in repoPkgs
          for arch in repoArchs
        ]
        + [
          mkRepo(arch)
          for arch in repoArchs
        ]
        + [
          buildImage(),
          publishImage(),
        ],
    }
  ),
]
