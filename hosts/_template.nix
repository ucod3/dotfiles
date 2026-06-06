# hosts/_template.nix — Template for adding a new machine
#
# INSTRUCTIONS:
#   1. Copy this file:  cp hosts/_template.nix hosts/<your-hostname>.nix
#      Where <your-hostname> = the output of `hostname -s` on the new machine.
#
#   2. Set `user` to the macOS account name on the new machine.
#
#   3. Register the host in flake.nix:
#        darwinConfigurations."<your-hostname>" = mkHost "<your-hostname>";
#
#   4. On the new machine, run:
#        rebuild
#      (the rebuild script resolves the hostname automatically)
#
# HOST-SPECIFIC OVERRIDES:
#   You can override anything from hosts/default.nix here.
#   For example, to add a machine-specific brew cask:
#
#     homebrew.casks = lib.mkAfter [ "my-extra-app" ];
#
#   Or to add extra Nix packages only on this machine:
#
#     environment.systemPackages = with pkgs; [ my-extra-tool ];

{ config, pkgs, lib, self, inputs, ... }:

let
  # ── Machine identity ───────────────────────────────────────────────────────
  # Set this to the macOS account username on the new machine.
  user = "REPLACE_WITH_USERNAME";

  nix-homebrew = inputs.nix-homebrew;
in
{
  imports = [
    ./default.nix
    nix-homebrew.darwinModules.nix-homebrew
    inputs.home-manager.darwinModules.home-manager
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true; # Set to false on Intel Macs
    user = user;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit user; };
    users.${user} = import ../nix/home/home.nix;
  };

  _module.args.user = user;

  # ── Host-specific overrides (optional) ────────────────────────────────────
  # Add machine-specific packages, settings, or overrides below.
  # Delete this section if you have no overrides.
}
