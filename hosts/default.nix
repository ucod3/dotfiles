# hosts/default.nix — Shared macOS system configuration
#
# This module is imported by every host. It contains settings that apply
# to all machines. Host-specific overrides live in hosts/<hostname>.nix.
#
# Arguments:
#   user  — the primary macOS username for this machine (set per-host)
#   self  — the flake self reference (for configurationRevision)

{ config, pkgs, self, user, ... }:

let
  # Gitignored local-settings layer (.local/ or ~/dotfiles-private).
  # Requires `--impure` + DOTFILES_LOCAL env — see scripts/bin/rebuild and
  # lib/local.nix for the empirically verified constraints. Under pure
  # evaluation this degrades to empty settings (nothing extra installed).
  dotfilesLocal = import ../lib/local.nix;
in
{
  # Optional application sets — each exposes dotfiles.apps.<set>.enable
  # (default: false, opt-in). Enable sets via `.local/settings.nix` or your
  # private host file:
  #   dotfiles.apps.browsers.enable = true;
  # See nix/modules/apps/, nix/modules/ai.nix, and hosts/_template.nix.
  imports = [ ../nix/modules/apps ../nix/modules/ai.nix ];

  system.primaryUser = user;

  nixpkgs.config.allowUnfree = true;

  # ── Homebrew Apps ──────────────────────────────────────────────────────────
  # HOW TO ADD/REMOVE APPS:
  #   Run: apps                    → interactive guide
  #        apps list               → see all installed apps
  #        apps search <name>      → find the right package name
  #        apps add <name>         → add to correct section automatically
  #        apps remove <name>      → remove from config
  #
  # Or edit this file manually, then run: rebuild
  #
  # WHICH SECTION TO USE?
  #   brews     → command-line tools (no .app, installed via brew install)
  #               Find names at: https://formulae.brew.sh/formula/
  #
  #   casks     → GUI apps with a .app bundle (installed via brew install --cask)
  #               Find names at: https://formulae.brew.sh/cask/
  #               Or run: brew search --cask <appname>
  #
  #   masApps   → Mac App Store apps (need Apple ID)
  #               Find ID: open App Store → right-click app → Copy Link → number in URL
  #               Format:  AppName = 1234567890;
  #
  #   systemPackages (below) → Nix packages, cross-platform
  #               Find names at: https://search.nixos.org/packages
  # ───────────────────────────────────────────────────────────────────────────
  homebrew = {
    enable = true;

    global = {
      autoUpdate = false;
      brewfile = true;
    };

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "uninstall"; # Removes apps no longer listed here
    };

    # Framework-core command-line tools (no GUI)
    # Find at: https://formulae.brew.sh/formula/
    # Taste-specific app sets live in nix/modules/apps/ (see imports above).
    brews = [
      "gitleaks"  # Git secret scanning (required by pre-commit hook)
      "sqlite"    # SQLite database
    ];

    # Framework-core GUI applications (.app bundles)
    # Find at: https://formulae.brew.sh/cask/  or  brew search --cask <name>
    # CUSTOMIZE: the framework core ships NO GUI apps. Terminal, browser,
    # editor, and window-manager choices come from the interactive installer
    # (written to .local/) or from your private host file.
    casks = dotfilesLocal.casks;
  };

  # ── Nix Packages ───────────────────────────────────────────────────────────
  # Cross-platform packages managed by Nix (not Homebrew)
  # Find names at: https://search.nixos.org/packages
  # These are available as CLI tools immediately after rebuild
  # ───────────────────────────────────────────────────────────────────────────
  environment.systemPackages = [
    pkgs.mkalias    # Create macOS aliases for Nix apps (framework glue)
    # neovim removed - installed via Home Manager to prevent duplication
    # Taste-specific packages (brave, gh, raycast) live in nix/modules/apps/
  ]
  # Nix packages selected by the interactive installer (from .local/)
  ++ map (name: pkgs.${name}) dotfilesLocal.nixPackages;

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    trusted-users = ["root" "@admin"];
  };

  programs.zsh.enable = true;

  # macOS System Optimizations
  system.defaults = {
    dock.autohide = true;
    finder.FXPreferredViewStyle = "clmv";
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleShowAllExtensions = true;
      NSAutomaticWindowAnimationsEnabled = false;
    };
  };

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };
}
