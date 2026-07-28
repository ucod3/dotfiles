{
  description = "Private macOS profile using the shared dotfiles framework";

  inputs = {
    dotfiles.url = "@DOTFILES_REF@";
    nixpkgs.follows = "dotfiles/nixpkgs";
    nix-darwin.follows = "dotfiles/nix-darwin";
    home-manager.follows = "dotfiles/home-manager";
    nix-homebrew.follows = "dotfiles/nix-homebrew";
  };

  outputs = inputs@{ self, dotfiles, nix-darwin, home-manager, nix-homebrew, ... }:
  let
    hostNames =
      let
        matched = map (file: builtins.match "(.*)\\.nix" file)
          (builtins.attrNames (builtins.readDir ./hosts));
      in
      map builtins.head (builtins.filter (match: match != null) matched);

    mkHost = name: nix-darwin.lib.darwinSystem {
      system = "@SYSTEM@";
      specialArgs = { inherit inputs self; };
      modules = [
        dotfiles.darwinModules.coreSystem
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
        (./hosts + "/${name}.nix")
      ];
    };
  in
  {
    darwinConfigurations = builtins.listToAttrs
      (map (name: { inherit name; value = mkHost name; }) hostNames);

    # The private profile owns the stable entry point while the pinned framework
    # owns the implementation. Running `nix run .#restore` therefore follows this
    # profile's flake.lock instead of a separately downloaded installer revision.
    apps."@SYSTEM@".restore = dotfiles.apps."@SYSTEM@".restore;
  };
}
