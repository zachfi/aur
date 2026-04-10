// build/packages.libsonnet — single source of truth for the package list.
//
// Imported by:
//   build/woodpecker.jsonnet  — generates .woodpecker.yml (CI pipeline)
//   build/packages.jsonnet    — generates build/packages.auto.mk (local make)
//
// To add a package:
//   1. Append to pkgs (respecting dep ordering — see comments below)
//   2. If it must be installed before a later package can build, add to localDeps
//   3. Run: make woodpecker
//   4. Commit packages.libsonnet, .woodpecker.yml, build/packages.auto.mk
{
  archs: ['x86_64'],

  // Packages installed into the build env immediately after building, so that
  // subsequent packages can satisfy runtime deps during makepkg.
  //   scenefx0.4 → provides 'scenefx0.4', required by mangowm (AUR only)
  localDeps: ['scenefx0.4'],

  // Build order matters: each localDep must appear before the package that
  // depends on it.
  pkgs: [
    'nodemanager-bin',
    'k3s-bin',
    'gomplate-bin',
    'duo_unix',
    'zen-browser-avx2-bin',
    'greetd-dms-greeter-git',
    'dsearch-bin',
    'scenefx0.4',            // must precede mangowm
    'mangowm',
    'openbgpd',
    'polychromatic',
  ],
}
