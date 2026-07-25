# Productivity application set (opt-in, disabled by default)
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ apps.productivity.enable = true; })
# or your private host file, and override the app lists below to taste.

{ config, lib, pkgs, dotfilesLocal, ... }:

let
  cfg = config.dotfiles.apps.productivity;
  pkgsByName = import ../../../lib/pkgs.nix;
in
{
  options.dotfiles.apps.productivity = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.appEnabled "productivity";
      description = "Install the productivity set (example profile: Amethyst, Insync, WPS Office via casks; Raycast via Nix).";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — replace with your own productivity casks
      default = [
        "amethyst"    # Window manager
        "insync"      # Google Drive sync
        "wpsoffice"   # Office suite
      ];
      description = "Homebrew casks installed when this set is enabled.";
    };

    nixPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — Nixpkgs attribute names
      default = [ "raycast" ];
      description = "Nixpkgs attribute names installed when this set is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
    environment.systemPackages =
      pkgsByName pkgs "dotfiles.apps.productivity.nixPackages" cfg.nixPackages;
  };
}
