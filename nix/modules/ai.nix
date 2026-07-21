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
      # CUSTOMIZE: example profile — AI desktop apps
      default = [ "devin-desktop" ];
      description = "Homebrew casks installed when AI tooling is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = cfg.casks;
  };
}
