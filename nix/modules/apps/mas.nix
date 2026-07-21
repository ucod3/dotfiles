# Mac App Store application set (opt-in, disabled by default)
#
# Requires an Apple ID signed into the App Store. The `mas` CLI is only
# installed when this set is enabled.
# Find app IDs: App Store → app page → right-click → Copy Link → number at end.
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ apps.mas.enable = true; })
# or your private host file, and override the `apps` list below to taste.

{ config, lib, dotfilesLocal, ... }:

let
  cfg = config.dotfiles.apps.mas;
in
{
  options.dotfiles.apps.mas = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.appEnabled "mas";
      description = "Install Mac App Store apps via the mas CLI (example profile: Notability).";
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      # CUSTOMIZE: example profile — AppName = <App Store ID>
      default = {
        Notability = 360593530;
      };
      description = "Mac App Store apps installed when this set is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [
      "mas" # Mac App Store CLI (required for masApps)
    ];

    homebrew.masApps = cfg.apps;
  };
}
