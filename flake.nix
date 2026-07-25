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
    inherit (nixpkgs) lib;

    darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];

    # Instantiate the exported modules against a throwaway host identity.
    # Returns the toplevel derivation; forcing its `drvPath` evaluates the
    # entire module tree (options, types, package attrs) without building it.
    # `extraModules` are darwin-level; `extraHomeModules` are Home Manager-level.
    # The two option namespaces are separate module systems — `dotfiles.home.*`
    # is only settable inside the latter.
    mkDummyHost =
      { system
      , user ? "dotfiles-check-user"
      , extraModules ? [ ]
      , extraHomeModules ? [ ]
      }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit self user inputs; };
        modules = [
          ./hosts/default.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit user; };
              users.${user}.imports = [ ./nix/home/home.nix ] ++ extraHomeModules;
            };
          }
        ] ++ extraModules;
      };

    # Evaluation-only check: the assert forces the full module evaluation, and
    # the resulting store path is deliberately NOT interpolated into the build
    # script — otherwise `nix flake check` would try to *build* a whole macOS
    # system rather than just type-check it.
    mkEvalCheck = name: args:
      let
        pkgs = nixpkgs.legacyPackages.${args.system};
        toplevel = (mkDummyHost args).config.system.build.toplevel;
      in
      assert toplevel.drvPath != "";
      pkgs.runCommand "dotfiles-check-${name}" { } "touch $out";
  in
  {
    # ═══════════════════════════════════════════════════════════════════════════
    # Evaluation Checks  (audit finding H2)
    # ═══════════════════════════════════════════════════════════════════════════
    # `darwinConfigurations` is intentionally empty (host identity lives in a
    # private downstream flake), which used to make `nix flake check` a no-op:
    # it never evaluated hosts/default.nix or nix/home/home.nix, so a broken
    # option name or a typo'd nixpkgs attribute passed validation cleanly.
    #
    # These checks close that gap by building the modules against a dummy host:
    #   cold — framework defaults only, mirroring a fresh public fork with no
    #          `.local/` layer. Guards the "installs nothing opinionated" and
    #          graceful-degradation contracts (ADR-004).
    #   full — every optional app set and opinionated home module enabled.
    #          Guards the bundled example profiles: every cask name is typed
    #          and every nixPackages attribute must actually exist in nixpkgs.
    checks = lib.genAttrs darwinSystems (system: {
      cold = mkEvalCheck "cold-${system}" { inherit system; };

      full = mkEvalCheck "full-${system}" {
        inherit system;
        extraModules = [{
          dotfiles = {
            apps.browsers.enable = true;
            apps.development.enable = true;
            apps.productivity.enable = true;
            apps.utilities.enable = true;
            apps.mas.enable = true;
            ai.enable = true;
            homebrew.cleanup = "uninstall";
            system.macosDefaults.enable = true;
          };
        }];
        extraHomeModules = [{
          dotfiles.home = {
            ohMyZsh.enable = true;
            ghostty.enable = true;
            vscode.enable = true;
            languageServers.enable = true;
            nodeTooling.enable = true;
          };
        }];
      };
    });

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
