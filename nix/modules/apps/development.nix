# Development application set (opt-in, disabled by default)
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ apps.development.enable = true; })
# or your private host file, and override the app lists below to taste.
# AI-specific apps (Devin Desktop) live in nix/modules/ai.nix instead.

{ config, lib, pkgs, dotfilesLocal, ... }:

let
  cfg = config.dotfiles.apps.development;
in
{
  options.dotfiles.apps.development = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.appEnabled "development";
      description = "Install the development set (example profile: Codex, Zed via casks; GitHub CLI via Nix).";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — replace with your own dev tool casks
      default = [
        "codex"
        "zed"
      ];
      description = "Homebrew casks installed when this set is enabled.";
    };

    nixPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — Nixpkgs attribute names
      default = [ "gh" ];
      description = "Nixpkgs attribute names installed when this set is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
    environment.systemPackages = map (name: pkgs.${name}) cfg.nixPackages;
  };
}
