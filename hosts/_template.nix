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
#       dotfiles.url = "git+file:///path/to/your/dotfiles";
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

  # ── 2. APPLICATION SETS — opt out of the upstream author's taste ──────────
  # All sets default to enabled. Disable any you don't want:
  #
  # dotfiles.apps.browsers.enable = false;      # Arc, Edge Canary, Zen, Brave
  # dotfiles.apps.development.enable = false;   # Codex, Devin Desktop, Zed, gh
  # dotfiles.apps.productivity.enable = false;  # Amethyst, Insync, WPS, Raycast
  # dotfiles.apps.utilities.enable = false;     # Acrobat, Antigravity, AnyDesk, Windscribe
  # dotfiles.apps.mas.enable = false;           # Mac App Store apps (Notability)

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
