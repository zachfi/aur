{
  local this = self,

  withRepoCache(dir='/repo'):: {
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
    this.withRepoCache('/repo')
    {
      name: 'repo',
      image: 'zachfi/shell:archlinux',
      pull: 'always',
      commands: [
        'whoami',
        'pwd',
        'ls -ld',
        'ls -l',
        'make repo',
      ],
    },
    this.withRepoCache('/repo')
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
