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
  {
    # ═══════════════════════════════════════════════════════════════════════════
    # Framework Module Exports
    # ═══════════════════════════════════════════════════════════════════════════
    # These modules are exported for downstream/private consumption. Host
    # configurations require a concrete macOS username and hostname, which
    # this shared repository intentionally does not hardcode. Instead, build
    # your host in a private downstream flake:
    #
    #   darwinConfigurations."<your-hostname>" = nix-darwin.lib.darwinSystem {
    #     system = "aarch64-darwin";
    #     modules = [
    #       dotfiles.darwinModules.coreSystem
    #       dotfiles.darwinModules.homeEnvironment
    #       # ... your private host identity and overrides
    #     ];
    #   };
    #
    # Run `./scripts/bin/setup-private-host` to generate this automatically,
    # or copy hosts/_template.nix for a documented manual starting point.
    # See docs/PRIVATE_HOST_SETUP.md for the full separation architecture.
    darwinModules = {
      coreSystem = ./hosts/default.nix;      # System-level defaults, packages, macOS settings
      homeEnvironment = ./nix/home/home.nix; # Home Manager configuration
    };

    darwinConfigurations = {
      # Host configurations belong in a private downstream flake because they
      # require a concrete macOS username and hostname.
      # See docs/PRIVATE_HOST_SETUP.md for the separation architecture.
    };
  };
}
