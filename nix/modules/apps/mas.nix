# Mac App Store application set (opt-in, enabled by default)
#
# Requires an Apple ID signed into the App Store. The `mas` CLI is only
# installed when this set is enabled.
# Find app IDs: App Store → app page → right-click → Copy Link → number at end.

{ config, lib, ... }:

let
  cfg = config.dotfiles.apps.mas;
in
{
  options.dotfiles.apps.mas.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install Mac App Store apps (Notability) via the mas CLI.";
  };

  config = lib.mkIf cfg.enable {
    homebrew.brews = [
      "mas" # Mac App Store CLI (required for masApps)
    ];

    homebrew.masApps = {
      Notability = 360593530;
    };
  };
}
