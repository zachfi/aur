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
                   + this.withRepoCache(),

  withRepoDir(dir=this.repoDir):: {
    environment+: {
      REPODIR: dir,
    },
  },

  withRepoCache(dir=this.repoDir):: {
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
    },
    this.new('publish')
    {
      commands: [
        'make publish',
      ],
      when: { branch: ['main'] },
    },
  ],
  volumes: [{ name: 'cache', temp: {} }],
  trigger: { event: ['push'] },
}
