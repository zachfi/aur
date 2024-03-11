{
  local this = self,

  kind: 'pipeline',
  name: 'ci',
  steps: [
    {
      name: 'repo',
      image: 'zachfi/build-image',
      pull: 'always',
      commands: [
        'make repo',
      ],
    },
    {
      name: 'image',
      image: 'zachfi/build-image',
      pull: 'always',
      commands: [
        'make imar',
      ],
    },
  ],
}
