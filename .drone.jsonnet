{
  local this = self,

  local repoDir = '/repo',

  withRepoCache(dir=repoDir):: {
    environment: {
      REPODIR: dir,
    },
    volumes: [
      {
        name: 'cache',
        path: dir,
      },
    ],
  },

  kind: 'pipeline',
  name: 'ci',
  steps: [
    this.withRepoCache()
    {
      name: 'repo',
      image: 'zachfi/shell:archlinux',
      pull: 'always',
      commands: [
        'sudo chown -R makepkg /drone',
        'git submodule',
        'make chown',
        'make repo',
      ],
    },
    this.withRepoCache()
    {
      name: 'image',
      image: 'zachfi/shell:archlinux',
      pull: 'always',
      commands: [
        'make image',
      ],
    },
  ],
  volumes: [{ name: 'cache', temp: {} }],
}
