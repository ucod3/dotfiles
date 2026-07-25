# lib/pkgs.nix — resolve Nixpkgs attribute names to packages, with a useful
# error message when a name is wrong.
#
# WHY (audit finding L5): the naive form
#
#   map (name: pkgs.${name}) cfg.nixPackages
#
# throws `attribute 'foo' missing` with no indication of which option list the
# bad name came from, which is painful when several app sets each contribute a
# list. This wrapper names both the offending attribute and its source.
#
# Usage:
#   let pkgsByName = import ../../lib/pkgs.nix; in
#   pkgsByName pkgs "dotfiles.apps.browsers.nixPackages" cfg.nixPackages

pkgs: source: names:
map
  (name:
    pkgs.${name} or (throw ''
      dotfiles: Nixpkgs has no package named '${name}' (listed in ${source}).
      Search for the correct attribute name at https://search.nixos.org/packages
      — note that GUI apps often need a Homebrew cask instead (see the `casks`
      option on the same module).
    '')
  )
  names
