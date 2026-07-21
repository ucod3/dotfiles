# nix/modules/apps — Optional, taste-specific application sets
#
# Each module defines a `dotfiles.apps.<set>.enable` toggle. All sets are
# OPT-IN (default: false) so a fresh clone installs nothing opinionated.
# Enable sets either:
#
#   * via the gitignored `.local/settings.nix` layer (written by install.sh):
#       { apps.browsers.enable = true; }
#   * or explicitly from your private host file:
#       dotfiles.apps.browsers.enable = true;
#
# The bundled lists are ONE example profile (the upstream author's taste).
# CUSTOMIZE: override the `casks`/`nixPackages` options per set, or replace
# the lists via `.local/browsers/choices.nix` etc.
# See hosts/_template.nix for a complete downstream example.

{ ... }:

{
  imports = [
    ./browsers.nix
    ./development.nix
    ./productivity.nix
    ./utilities.nix
    ./mas.nix
  ];

  # Expose the .local loader to every app module as `dotfilesLocal`
  _module.args.dotfilesLocal = import ../../../lib/local.nix;
}
