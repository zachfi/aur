local repoArchs = ['x86_64'];
local repoPkgs = ['nodemanager-bin'];
local image = 'zachfi/shell:latest';

local pipeline(name) = {
  kind: 'pipeline',
  name: name,
  steps: [],
  depends_on: [],
  volumes: [
    { name: 'cache', temp: {} },
    { name: 'dockersock', host: { path: '/var/run/docker.sock' } },
  ],
};

local step(name) = {
  name: name,
  image: image,
  // pull: 'always',
};

local initRepo(arch) = {
  local dir = '/repo/%s' % arch,

  name: 'init-repo-%s' % arch,
  image: image,
  commands: [
    // 'sudo mkdir -p /repo/%s' % arch,
    'sudo chown -R makepkg /repo',
    'sudo chown -R makepkg /drone',
    'git submodule init',
    'git submodule update',
  ],
  volumes+: [
    { name: 'cache', path: dir },
  ],
};

local buildPkg(pkg, arch) = {
  local dir = '/repo/%s' % arch,

  name: 'build-pkg-%s' % pkg,
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
    { name: 'cache', path: dir },
  ],
};

local mkRepo(arch) = {
  local dir = '/repo/%s' % arch,

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
    { name: 'cache', path: dir },
  ],
};

local buildImage(arch) = {
  local dir = '/repo/%s' % arch,

  name: 'build-image-%s' % arch,
  image: image,
  commands:
    [
      'sudo docker build -t zachfi/aur:%(arch)s -f Dockerfile %(dir)s' % { dir: dir, arch: arch },
    ],
  volumes+: [
    { name: 'cache', path: dir },
    { name: 'dockersock', path: '/var/run/docker.sock' },
  ],
};

local publishImage(arch) = {
  local dir = '/repo/%s' % arch,

  name: 'publish-image-%s' % arch,
  image: image,
  commands:
    [
      'echo $DOCKER_PASSWORD | sudo docker login --username $DOCKER_USERNAME --password-stdin',
      'sudo docker push zachfi/aur:%(arch)s' % { arch: arch },
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
    pipeline('ci-%s' % arch) {
      steps:
        [
          initRepo(arch),
        ]
        + [
          buildPkg(pkg, arch)
          for pkg in repoPkgs
        ]
        + [
          mkRepo(arch),
          buildImage(arch),
          publishImage(arch),
        ],
    }
  )
  for arch in repoArchs
] + [
  // {
  //   local this = self,
  //
  //   repoDir:: '/repo',
  //
  //   step(name=name):: {
  //     name: name,
  //     image: image,
  //     pull: 'always',
  //   }
  //   // + this.withRepoDir()
  //   // + this.withRepoCache()
  //   // + this.withDockerSocket()
  //   ,
  //
  //   withRepoDir(dir=this.repoDir):: {
  //     environment+: {
  //       REPODIR: dir,
  //     },
  //   },
  //
  //   withRepoCache(dir=this.repoDir):: {
  //     volumes+: [
  //       {
  //         name: 'cache',
  //         path: dir,
  //       },
  //     ],
  //   },
  //
  //   withDockerSocket():: {
  //     volumes+: [
  //       {
  //         name: 'dockersock',
  //         path: '/var/run/docker.sock',
  //       },
  //     ],
  //   },
  //
  //   kind: 'pipeline',
  //   name: 'ci',
  //   steps: [
  //     this.step('chown')
  //     {
  //       commands: [
  //         'sudo chown -R makepkg /drone',
  //         'sudo chown -R makepkg /repo',
  //       ],
  //     },
  //     this.step('submodules')
  //     {
  //       commands: [
  //         'make modules',
  //       ],
  //     },
  //     this.step('repo')
  //     {
  //       commands: [
  //         'make repo',
  //       ],
  //     },
  //     this.step('image')
  //     {
  //       commands: [
  //         'make image',
  //       ],
  //     },
  //     this.step('publish')
  //     {
  //       commands: [
  //         'make publish',
  //       ],
  //       when: { branch: ['main'] },
  //     },
  //   ],
  //   volumes: [
  //     { name: 'cache', temp: {} },
  //     { name: 'dockersock', host: { path: '/var/run/docker.sock' } },
  //   ],
  //   trigger: { event: ['push'] },
  // },
]
