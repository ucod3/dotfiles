# Homebrew activation policy
#
# WHY THIS MODULE EXISTS (ADR-006 / audit finding H1):
#   `homebrew.onActivation.cleanup = "uninstall"` makes Homebrew uninstall
#   every cask not declared by this flake. The framework core ships NO casks —
#   they come from the gitignored `.local/` layer. So on a cold public fork,
#   where `.local/` is absent and the declared cask set is empty, an
#   unconditional "uninstall" would wipe every Homebrew cask already installed
#   on that person's machine on their very first `dot rebuild`.
#
#   The cleanup mode is therefore gated: it stays "none" (non-destructive)
#   unless a local settings layer is present, or you opt in explicitly.
#
# CUSTOMIZE: from your private host file or `.local/settings.nix`:
#   dotfiles.homebrew.cleanup = "uninstall";  # prune undeclared casks
#   dotfiles.homebrew.cleanup = "zap";        # prune + remove app data
#   dotfiles.homebrew.cleanup = "none";       # never prune (safest)

{ config, lib, ... }:

let
  dotfilesLocal = import ../../lib/local.nix;
  cfg = config.dotfiles.homebrew;
in
{
  options.dotfiles.homebrew = {
    cleanup = lib.mkOption {
      type = lib.types.enum [ "none" "uninstall" "zap" ];

      # Default is DELIBERATELY conservative. `.local/` present means someone
      # ran install.sh or linked a private flake — they have a declared cask
      # set, so pruning is meaningful. No `.local/` means a cold clone with an
      # empty cask set, where pruning is purely destructive.
      default = if dotfilesLocal.exists then "uninstall" else "none";
      defaultText = lib.literalExpression ''if <.local/ exists> then "uninstall" else "none"'';

      description = ''
        Homebrew `onActivation.cleanup` mode.

        "none" leaves undeclared casks alone. "uninstall" removes any cask not
        declared by this configuration. "zap" also deletes their app data.

        Never defaults to a destructive value on a fresh clone — see ADR-006.
      '';
    };
  };

  config = {
    homebrew.onActivation.cleanup = cfg.cleanup;

    # Make the non-obvious safe default visible at build time rather than
    # letting a fork silently wonder why stale casks are never pruned.
    warnings = lib.optional (cfg.cleanup == "none" && !dotfilesLocal.exists) ''
      dotfiles: homebrew cleanup is "none" because no .local/ settings layer was
      found. Undeclared Homebrew casks will NOT be uninstalled. Set
      `dotfiles.homebrew.cleanup = "uninstall"` once your cask list is complete.
    '';
  };
}
