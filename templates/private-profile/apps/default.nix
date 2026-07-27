{ pkgs, lib, ... }:

let
  casks = import ./homebrew-casks.nix;
  nixPackages = import ./nix-packages.nix { inherit pkgs; };
  masApps = import ./mac-app-store.nix;
in
{
  homebrew.casks = casks;
  homebrew.masApps = masApps;
  homebrew.brews = lib.optional (masApps != { }) "mas";

  environment.systemPackages = nixPackages;

  # Never remove undeclared applications until the owner opts in after reviewing
  # the complete list above.
  dotfiles.homebrew.cleanup = "none";
}
