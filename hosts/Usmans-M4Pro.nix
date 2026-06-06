# hosts/Usmans-M4Pro.nix — Host configuration for Usman's M4 Pro MacBook
#
# This file is the single source of truth for this machine's identity.
# The flake.nix builds darwinConfigurations."Usmans-M4Pro" using this file.
#
# To add a new machine: copy hosts/_template.nix → hosts/<hostname>.nix,
# fill in the user and any overrides, then register it in flake.nix.

{ config, pkgs, lib, self, inputs, ... }:

let
  # ── Machine identity ───────────────────────────────────────────────────────
  # The primary macOS username on this machine.
  # Change this if the account name differs on a new machine.
  user = "usmanbutt";

  # nix-homebrew shorthand (re-bound from inputs in flake.nix specialArgs)
  nix-homebrew = inputs.nix-homebrew;
in
{
  imports = [
    # Shared system configuration (Homebrew apps, Nix packages, macOS defaults)
    ./default.nix

    # nix-homebrew module
    nix-homebrew.darwinModules.nix-homebrew

    # Home Manager module
    inputs.home-manager.darwinModules.home-manager
  ];

  # ── nix-homebrew ─────────────────────────────────────────────────────────
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = user;
    autoMigrate = true;
  };

  # ── Home Manager ──────────────────────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit user; };
    users.${user} = import ../nix/home/home.nix;
  };

  # ── Pass user down to shared config ───────────────────────────────────────
  # default.nix receives `user` via specialArgs set in flake.nix.
  # This attribute makes it explicit at the host level as well.
  _module.args.user = user;
}
