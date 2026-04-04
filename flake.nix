{
  description = "ucod3's macOS nix-darwin + Home Manager + Homebrew setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }@inputs: {
    darwinConfigurations.m4pro = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit self inputs; };

      modules = [
        ./nix/darwin/configuration.nix

        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "usmanbutt";
            autoMigrate = true;
          };
        }

        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-backup";

          home-manager.users.usmanbutt = import ./nix/home/home.nix;
        }
      ];
    };
  };
}