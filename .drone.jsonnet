{
  local this = self,

  repoDir:: '/repo',
  image:: 'zachfi/shell:latest',

  new(name=name):: {
                     name: name,
                     image: this.image,
                     pull: 'always',
                   }
                   + this.withRepoDir()
                   + this.withRepoCache()
                   + this.withDockerSocket()
  ,

  withRepoDir(dir=this.repoDir):: {
    environment+: {
      REPODIR: dir,
    },
  },

  withRepoCache(dir=this.repoDir):: {
    volumes+: [
      {
        name: 'cache',
        path: dir,
      },
    ],
  },

  withDockerSocket():: {
    volumes+: [
      {
        name: 'docker.sock',
        host: {
          path: '/var/run/docker.sock',
        },
      },
    ],
  },

  kind: 'pipeline',
  name: 'ci',
  steps: [
    this.new('chown')
    {
      commands: [
        'sudo chown -R makepkg /drone',
        'sudo chown -R makepkg /repo',
      ],
    },
    this.new('submodules')
    {
      commands: [
        'make modules',
      ],
    },
    this.new('repo')
    {
      commands: [
        'make repo',
      ],
    },
    this.new('image')
    {
      commands: [
        'make image',
      ],
      volumes: [
        {
          name: 'docker.sock',
          path: '/var/run/docker.sock',
        },
      ],
    },
    this.new('publish')
    {
      commands: [
        'make publish',
      ],
      volumes: [
        {
          name: 'docker.sock',
          path: '/var/run/docker.sock',
        },
      ],
      when: { branch: ['main'] },
    },
  ],
  volumes: [{ name: 'cache', temp: {} }],
  trigger: { event: ['push'] },
}
