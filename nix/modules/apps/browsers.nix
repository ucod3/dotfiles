# Browser application set (opt-in, disabled by default)
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ apps.browsers.enable = true; })
# or your private host file, and override the app lists below to taste.

{ config, lib, pkgs, dotfilesLocal, ... }:

let
  cfg = config.dotfiles.apps.browsers;
in
{
  options.dotfiles.apps.browsers = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.appEnabled "browsers";
      description = "Install the browser set (example profile: Arc, Microsoft Edge Canary, Zen via casks; Brave via Nix).";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — replace with your own browser casks
      default = [
        "arc"
        "microsoft-edge@canary"
        "zen"
      ];
      description = "Homebrew casks installed when this set is enabled.";
    };

    nixPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — Nixpkgs attribute names
      default = [ "brave" ];
      description = "Nixpkgs attribute names installed when this set is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
    environment.systemPackages = map (name: pkgs.${name}) cfg.nixPackages;
  };
}
