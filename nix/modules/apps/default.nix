# nix/modules/apps — Optional, taste-specific application sets
#
# Each module defines a `dotfiles.apps.<set>.enable` toggle (default: true,
# preserving the upstream author's setup). Downstream forks disable any set
# from their private host file:
#
#   dotfiles.apps.browsers.enable = false;
#   dotfiles.apps.mas.enable = false;
#
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
}
