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
        'whoami',
        'pwd',
        'ls -ld',
        'ls -l',
        'ls -ld /repo',
        'sudo chown -R makepkg %s' % repoDir,
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
