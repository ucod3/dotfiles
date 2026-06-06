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

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }@inputs:
  let
    # mkHost — build a darwinSystem from a host file in hosts/<hostname>.nix
    #
    # The host file is the single source of truth for:
    #   - the primary macOS username (user = "...")
    #   - nix-homebrew and home-manager wiring
    #   - any machine-specific overrides
    #
    # To add a new machine:
    #   cp hosts/_template.nix hosts/<hostname>.nix   # hostname -s output
    #   # fill in user = "..."
    #   darwinConfigurations."<hostname>" = mkHost "<hostname>";
    mkHost = hostname: nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit self inputs; };
      modules = [ ./hosts/${hostname}.nix ];
    };
  in
  {
    # ── Registered machines ───────────────────────────────────────────────────
    # Key  = output of `hostname -s` on the machine (used by rebuild script)
    # Value = mkHost "<hostname>"
    darwinConfigurations = {
      "Usmans-M4Pro" = mkHost "Usmans-M4Pro";
    };
  };
}
