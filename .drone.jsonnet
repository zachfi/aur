{
  local this = self,

  kind: 'pipeline',
  name: 'ci',
  steps: [
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
      environment: {
        REPODIR: '/repo',
      },
      volumes: [
        {
          name: 'cache',
          path: '/repo',
        },
      ],
    },
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
