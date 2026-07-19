# Development application set (opt-in, enabled by default)

{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.apps.development;
in
{
  options.dotfiles.apps.development.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install the development set: Codex, Devin Desktop, Zed (casks) and GitHub CLI (Nix).";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [
      "codex"
      "devin-desktop"
      "zed"
    ];

    environment.systemPackages = [
      pkgs.gh # GitHub CLI
    ];
  };
}
