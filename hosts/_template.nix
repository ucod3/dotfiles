# hosts/_template.nix — Downstream host template (NOT imported by anything)
#
# HOW TO USE THIS TEMPLATE
# ─────────────────────────
# The public framework intentionally ships no host configurations. Your
# machine identity (hostname + username) lives in a separate private flake.
#
# Recommended: generate everything automatically:
#
#   ./scripts/bin/setup-private-host
#
# Manual setup: copy this file to ~/dotfiles-private/hosts/<your-hostname>.nix
# and reference it from a private flake like this:
#
#   {
#     inputs = {
#       # Pin a PUBLISHED revision. Your live system should never depend on a
#       # branch or working tree that exists only on one machine (ADR-009).
#       # `dot rebuild --override-local` is the opt-in way to test local work.
#       dotfiles.url = "github:<your-github-user>/dotfiles";
#       nixpkgs.follows = "dotfiles/nixpkgs";
#       nix-darwin.follows = "dotfiles/nix-darwin";
#       home-manager.follows = "dotfiles/home-manager";
#       nix-homebrew.follows = "dotfiles/nix-homebrew";
#     };
#     outputs = inputs@{ self, dotfiles, nix-darwin, home-manager, nix-homebrew, ... }: {
#       darwinConfigurations."<your-hostname>" = nix-darwin.lib.darwinSystem {
#         system = "aarch64-darwin";
#         specialArgs = { inherit inputs self; };
#         modules = [
#           dotfiles.darwinModules.coreSystem
#           nix-homebrew.darwinModules.nix-homebrew
#           home-manager.darwinModules.home-manager
#           ./hosts/<your-hostname>.nix
#         ];
#       };
#     };
#   }
#
# Then build with: dot rebuild   (or: darwin-rebuild switch --flake .#<your-hostname>)

{ inputs, ... }:

let
  # 1. IDENTITY — set your macOS username (output of: id -un)
  user = "your-macos-username";
in
{
  # ── Framework wiring (required, copy as-is) ────────────────────────────────
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = user;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit user; };
    users.${user} = import inputs.dotfiles.darwinModules.homeEnvironment;
  };

  # Inject your username into every framework module that needs it
  _module.args.user = user;

  # ── 2. APPLICATIONS — declared in .local/settings.nix, not here ───────────
  # The framework names no application anywhere, so there is nothing here to
  # opt out of. Everything you want goes in the gitignored
  # `.local/settings.nix` (written by install.sh, then yours to edit):
  #
  #   casks       = [ "firefox" "ghostty" ];   # https://formulae.brew.sh/cask/
  #   nixPackages = [ "htop" ];                # https://search.nixos.org/packages
  #   masApps     = { Notability = 360593530; };
  #
  # Keeping them in one list — rather than five per-category modules whose
  # defaults named the upstream author's own apps — is what makes deleting an
  # entry actually uninstall it.
  #
  # dotfiles.ai.enable = true;                 # AI editor config symlinks

  # ── 2b. SYSTEM POSTURE — safe defaults on a cold fork ─────────────────────
  # Homebrew pruning is OFF unless a .local/ layer exists, because the core
  # ships no casks and "uninstall" would remove YOUR existing apps (ADR-006):
  # dotfiles.homebrew.cleanup = "uninstall";   # prune undeclared casks
  #
  # The macOS defaults profile (Dock autohide, key repeat, column view) is
  # opinionated — note it disables press-and-hold accent entry:
  # dotfiles.system.macosDefaults.enable = true;
  # dotfiles.nixpkgs.allowUnfree = false;      # strict free-software posture
  #
  # ── 2c. HOME PROFILE — taste-specific user config (Home Manager namespace) ─
  # These live under home-manager.users.<you>, not at the system level.
  # Everything here defaults to OFF on a cold fork: a framework must not decide
  # what `cd`, `npm` or `git pull` do on your machine (ADR-011).
  # home-manager.users.${user}.dotfiles.home = {
  #   ohMyZsh.enable = true;          # omz framework, theme, plugins
  #   ohMyZsh.theme = "agnoster";     # CUSTOMIZE
  #   ghostty.enable = true;          # link the bundled Ghostty config
  #   vscode.enable = true;           # link the bundled settings.json
  #   vscode.configDir = "Code";      # "Code" (default) / "Code - Insiders" / "VSCodium"
  #   cursor.enable = true;           # same settings.json, Cursor's config dir
  #   languageServers.enable = true;  # lua-language-server, pyright, ts-ls
  #   nodeTooling.enable = true;      # pnpm
  #
  #   # Shell composition. The neutral core (dot aliases, mkcd, direnv hook) is
  #   # always on; these add the layers that redefine existing commands.
  #   zsh.personalAliases.enable = true;  # ll/la, grep --color, help=man, npm→pnpm
  #   zsh.nodeWorkflow.enable = true;     # pnpm/pnpx wrappers, ensure-node, real-npm
  #   zsh.workshop.enable = true;         # EpicWeb helpers — NOTE: its chpwd hook
  #                                       # writes .workshop.env into matching
  #                                       # projects. Requires nodeWorkflow.
  #   zoxide.replaceCd = true;            # zoxide takes over `cd` (default: `z` only)
  #   git.opinionatedDefaults.enable = true;  # nvim as editor, pull.rebase, nvimdiff
  # };
  #
  # For YOUR OWN aliases and tool setup, do not edit this repo at all — use the
  # unmanaged, gitignored config/zsh/custom.local.zsh or ~/.zshrc.local, which
  # are sourced last. See config/zsh/custom.local.zsh.example.

  # ── 3. MACHINE-SPECIFIC ADDITIONS (examples) ───────────────────────────────
  # Extra Homebrew apps for this machine only:
  # homebrew.casks = [ "firefox" ];
  # homebrew.brews = [ "jq" ];
  #
  # Extra Nix packages:
  # environment.systemPackages = [ pkgs.htop ];  # add pkgs to the arg set above
  #
  # Override macOS defaults from hosts/default.nix:
  # system.defaults.dock.autohide = false;
  # system.defaults.NSGlobalDomain.KeyRepeat = 1;
}
