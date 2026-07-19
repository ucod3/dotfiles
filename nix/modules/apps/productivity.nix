# Productivity application set (opt-in, enabled by default)

{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.apps.productivity;
in
{
  options.dotfiles.apps.productivity.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the productivity set: Amethyst, Insync, WPS Office (casks) and Raycast (Nix).";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [
      "amethyst"    # Window manager
      "insync"      # Google Drive sync
      "wpsoffice"   # Office suite
    ];

    environment.systemPackages = [
      pkgs.raycast # Spotlight replacement
    ];
  };
}
