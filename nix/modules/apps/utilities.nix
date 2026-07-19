# Utility application set (opt-in, enabled by default)

{ config, lib, ... }:

let
  cfg = config.dotfiles.apps.utilities;
in
{
  options.dotfiles.apps.utilities.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the utility set: Adobe Acrobat Reader, Antigravity, AnyDesk, Windscribe (casks).";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [
      "adobe-acrobat-reader"
      "antigravity"
      "anydesk"     # Remote desktop
      "windscribe"  # VPN
    ];
  };
}
