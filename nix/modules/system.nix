# System-level posture toggles (macOS defaults + licensing)
#
# WHY THIS MODULE EXISTS (audit findings M3 / M4):
#   `hosts/default.nix` used to hardcode a block of `system.defaults` and
#   `nixpkgs.config.allowUnfree`. Both are personal-taste decisions that a
#   public fork inherits silently. In particular
#   `ApplePressAndHoldEnabled = false` disables the accent-character picker,
#   which is a real regression for anyone typing a non-English language.
#
# CUSTOMIZE: from your private host file or `.local/settings.nix`:
#   dotfiles.system.macosDefaults.enable = true;   # adopt the example profile
#   dotfiles.nixpkgs.allowUnfree = false;          # strict free-software posture

{ config, lib, ... }:

let
  dotfilesLocal = import ../../lib/local.nix;
  cfg = config.dotfiles.system;
in
{
  options.dotfiles = {
    system.macosDefaults = {
      enable = lib.mkOption {
        type = lib.types.bool;
        # Same rationale as dotfiles.homebrew.cleanup: a machine with a local
        # settings layer opted into this framework's profile; a cold fork did
        # not, and should get stock macOS behaviour until it asks otherwise.
        default = dotfilesLocal.exists;
        defaultText = lib.literalExpression "<true when a .local/ layer exists>";
        description = ''
          Apply the example macOS system defaults (Dock autohide, Finder column
          view, faster key repeat, no window animations).

          Individual keys can still be overridden per-host — this toggle only
          controls whether the bundled example profile is applied at all.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        # CUSTOMIZE: example profile — replace wholesale or override per key.
        default = {
          dock.autohide = true;
          finder.FXPreferredViewStyle = "clmv";
          NSGlobalDomain = {
            # NOTE: disabling press-and-hold trades the accent picker for key
            # repeat. Opinionated, and off by default on cold forks for exactly
            # that reason.
            ApplePressAndHoldEnabled = false;
            KeyRepeat = 2;
            InitialKeyRepeat = 15;
            AppleShowAllExtensions = true;
            NSAutomaticWindowAnimationsEnabled = false;
          };
        };
        description = "macOS `system.defaults` applied when macosDefaults is enabled.";
      };
    };

    nixpkgs.allowUnfree = lib.mkOption {
      type = lib.types.bool;
      # Defaults true: Homebrew casks and most GUI tooling on darwin are
      # unfree, so flipping this off by default would make the bundled example
      # profiles fail with confusing licence errors rather than teaching
      # anything. Kept as an explicit, documented opt-out instead of an
      # unconditional assignment.
      default = true;
      description = ''
        Allow unfree Nixpkgs packages. Set to false for a strict free-software
        posture — note that several bundled example packages will then need to
        be removed from the enabled app sets.
      '';
    };
  };

  config = {
    nixpkgs.config.allowUnfree = config.dotfiles.nixpkgs.allowUnfree;
    system.defaults = lib.mkIf cfg.macosDefaults.enable cfg.macosDefaults.settings;
  };
}
