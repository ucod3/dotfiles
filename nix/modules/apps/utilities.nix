# Utility application set (opt-in, disabled by default)
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ apps.utilities.enable = true; })
# or your private host file, and override the app lists below to taste.

{ config, lib, dotfilesLocal, ... }:

let
  cfg = config.dotfiles.apps.utilities;
in
{
  options.dotfiles.apps.utilities = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.appEnabled "utilities";
      description = "Install the utility set (example profile: Adobe Acrobat Reader, Antigravity, AnyDesk, Windscribe via casks).";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # CUSTOMIZE: example profile — replace with your own utility casks
      default = [
        "adobe-acrobat-reader"
        "antigravity"
        "anydesk"     # Remote desktop
        "windscribe"  # VPN
      ];
      description = "Homebrew casks installed when this set is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
  };
}
