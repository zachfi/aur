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
        'make repo',
      ],
    },
    {
      name: 'image',
      image: 'zachfi/shell:archlinux',
      pull: 'always',
      commands: [
        'make imar',
      ],
    },
  ],
}
