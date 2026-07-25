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

      # Default is DELIBERATELY non-destructive, always. Pruning is opt-in per
      # machine via `.local/settings.nix`; the mere presence of a settings
      # layer is NOT consent to uninstall software (ADR-007). An earlier
      # version defaulted to "uninstall" whenever a `.local/` directory
      # existed, which fired on bare directories with an empty cask list.
      default =
        if dotfilesLocal.homebrewCleanup != null
        then dotfilesLocal.homebrewCleanup
        else "none";
      defaultText = lib.literalExpression ''.local/settings.nix `homebrew.cleanup`, else "none"'';

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

    # Hard stop. Pruning against an empty declared set is always mass deletion,
    # never intent — so refuse to evaluate rather than trusting the default to
    # have been computed correctly. This is what makes the wipe unreachable.
    assertions = [{
      assertion = cfg.cleanup == "none" || config.homebrew.casks != [ ];
      message = ''
        dotfiles: homebrew cleanup is "${cfg.cleanup}" but the declared cask list
        is EMPTY. Activating this would uninstall every Homebrew cask on this
        machine. Declare your casks in .local/settings.nix first, or set
        `dotfiles.homebrew.cleanup = "none"`.
      '';
    }];

    # Make the non-obvious safe default visible at build time rather than
    # letting someone silently wonder why stale casks are never pruned. Gated on
    # `exists`: a machine with no settings layer has nobody to advise yet.
    warnings = lib.optional (cfg.cleanup == "none" && dotfilesLocal.exists) ''
      dotfiles: homebrew cleanup is "none", so undeclared Homebrew casks will NOT
      be uninstalled. Set `homebrew.cleanup = "uninstall";` in
      .local/settings.nix once your cask list is complete.
    '';
  };
}
