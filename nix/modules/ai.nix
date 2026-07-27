# AI tooling (opt-in, disabled by default)
#
# Gates Devin-specific applications at the system level. The matching
# Home Manager config symlinks (Windsurf/Devin configs) are gated on the
# same `.local` flag inside nix/home/home.nix.
#
# CUSTOMIZE: enable via `.local/settings.nix` ({ ai.enable = true; })
# or your private host file (dotfiles.ai.enable = true;).
# The tracked `.devin/` rules and skills are inert unless you use Devin CLI.

{ config, lib, ... }:

let
  cfg = config.dotfiles.ai;
  dotfilesLocal = import ../../lib/local.nix;
in
{
  options.dotfiles.ai = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = dotfilesLocal.aiEnabled;
      description = "Install AI tooling (Devin Desktop cask) and enable AI editor config symlinks.";
    };

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Empty on purpose. This used to default to [ "devin-desktop" ], so
      # `ai.enable = true` silently installed a specific vendor's desktop app.
      # Applications belong in `.local/settings.nix` `casks`, where you can see
      # and remove them; this toggle now governs only the editor config
      # symlinks in nix/home/home.nix.
      default = [ ];
      description = "Extra Homebrew casks to install when AI tooling is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
  };
}
