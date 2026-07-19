# Browser application set (opt-in, enabled by default)

{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.apps.browsers;
in
{
  options.dotfiles.apps.browsers.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the browser set: Arc, Microsoft Edge Canary, Zen (casks) and Brave (Nix).";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [
      "arc"
      "microsoft-edge@canary"
      "zen"
    ];

    environment.systemPackages = [
      pkgs.brave # Browser (via Nix)
    ];
  };
}
