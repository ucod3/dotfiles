{
  description = "A modular, clone-and-run macOS development environment framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }@inputs:
  let
    # mkHost — build a darwinSystem for a given hostname and username
    #
    # This helper creates a complete macOS configuration that:
    #   - Imports shared system defaults from hosts/default.nix
    #   - Sets up nix-homebrew with the specified user
    #   - Configures Home Manager for the specified user
    #
    # Arguments:
    #   hostname: The machine hostname (must match `hostname -s` output)
    #   username: The primary macOS username for Home Manager and Homebrew
    mkHost = hostname: username: nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit self inputs; };
      modules = [
        # Shared system configuration (Homebrew apps, Nix packages, macOS defaults)
        ./hosts/default.nix

        # nix-homebrew module
        nix-homebrew.darwinModules.nix-homebrew

        # Home Manager module
        home-manager.darwinModules.home-manager

        # Host-specific configuration inline
        {
          # nix-homebrew setup
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = username;
            autoMigrate = true;
          };

          # Home Manager setup
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-backup";
            extraSpecialArgs = { user = username; };
            users.${username} = import ./nix/home/home.nix;
          };

          # Pass user down to shared config
          _module.args.user = username;
        }
      ];
    };
  in
  {
    # ═══════════════════════════════════════════════════════════════════════════
    # LAYER A: Framework Module Exports
    # ═══════════════════════════════════════════════════════════════════════════
    # These modules are exported for downstream/private consumption.
    # Import them in your private flake to build custom configurations:
    #
    #   darwinConfigurations.my-machine = nix-darwin.lib.darwinSystem {
    #     modules = [
    #       dotfiles-framework.darwinModules.coreSystem
    #       dotfiles-framework.darwinModules.homeEnvironment
    #       # ... your private config
    #     ];
    #   };
    #
    darwinModules = {
      coreSystem = ./hosts/default.nix;      # System-level defaults, packages, macOS settings
      homeEnvironment = ./nix/home/home.nix; # Home Manager configuration
    };

    # ═══════════════════════════════════════════════════════════════════════════
    # LAYER B: Clone-and-Run Dynamic Deployments
    # ═══════════════════════════════════════════════════════════════════════════
    # Pre-built configurations for immediate use. These provide a
    # "git clone && ./install.sh" experience for casual forkers.
    #
    # The rebuild script falls back to "default" if your hostname
    # isn't explicitly mapped here.
    darwinConfigurations = {
      # Default fallback configuration for quick testing/generic installs
      # Uses generic "user" account name — change after install or use
      # the exported modules for custom setups.
      "default" = mkHost "default" "user";

      # Example configuration — replace with your own hostname in a private downstream flake
      # See docs/DEVIN_SETUP.md for the separation architecture
      # "my-macbook" = mkHost "my-macbook" "myuser";
    };
  };
}
