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

    # Apple Silicon only. x86_64-darwin was previously listed here, but nothing
    # in the repo was ever tested on Intel and `setup-private-host` hardcoded
    # aarch64-darwin — so the claim was advertising something that could not
    # build. Add "x86_64-darwin" back only alongside a machine that verifies it.
    darwinSystems = [ "aarch64-darwin" ];

    # Instantiate the exported modules against a throwaway host identity.
    # Returns the toplevel derivation; forcing its `drvPath` evaluates the
    # entire module tree (options, types, package attrs) without building it.
    # `extraModules` are darwin-level; `extraHomeModules` are Home Manager-level.
    # The two option namespaces are separate module systems — `dotfiles.home.*`
    # is only settable inside the latter.
    # Named rather than inlined because cold-is-nondestructive has to reach
    # back into `config.home-manager.users.<user>` to assert the resolved Home
    # Manager values, and a second literal copy would silently stop matching.
    dummyUser = "dotfiles-check-user";

    mkDummyHost =
      { system
      , user ? dummyUser
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
    #   cold-is-nondestructive — pins the ADR-007 and ADR-011 contracts: a
    #          fresh fork must never resolve to a destructive default, and
    #          never to a shell that redefines commands the user already has.
    checks = lib.genAttrs darwinSystems (system: {
      cold = mkEvalCheck "cold-${system}" { inherit system; };

      # Regression guard for ADR-007. A cold fork once resolved
      # `homebrew.onActivation.cleanup` to "uninstall" with an empty declared
      # cask list, which uninstalls every cask on the machine. Assert the
      # resolved values directly so that can never silently come back.
      cold-is-nondestructive =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          host = mkDummyHost { inherit system; };
          homeCfg = host.config.home-manager.users.${dummyUser};
        in
        assert host.config.homebrew.onActivation.cleanup == "none";
        assert !host.config.dotfiles.system.macosDefaults.enable;

        # ADR-011, the shell half of the same contract. A cold fork must not
        # get a shell that redefines commands the user already has, and these
        # are the three that actually reached outside this repo:
        #
        #   zoxide --cmd cd  shadowed the `cd` builtin
        #   workshop.zsh     wrote .workshop.env, and appended to .gitignore,
        #                    in whatever project you cd'd into
        #   aliases-personal aliased npm and yarn to pnpm machine-wide
        #
        # Asserting the resolved values means re-imposing any of them fails
        # the check rather than shipping quietly, exactly as the Homebrew
        # cleanup assertion above does for ADR-007.
        assert homeCfg.programs.zoxide.options == [ ];
        assert !homeCfg.dotfiles.home.zsh.workshop.enable;
        assert !homeCfg.dotfiles.home.zsh.personalAliases.enable;
        assert !homeCfg.dotfiles.home.zsh.nodeWorkflow.enable;
        assert !homeCfg.dotfiles.home.git.opinionatedDefaults.enable;
        pkgs.runCommand "dotfiles-check-cold-nondestructive-${system}" { } "touch $out";

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
          # The cleanup assertion refuses "uninstall" against an empty cask
          # list, so a fully-enabled host must declare at least one cask.
          homebrew.casks = [ "ghostty" ];
        }];
        extraHomeModules = [{
          dotfiles.home = {
            ohMyZsh.enable = true;
            ghostty.enable = true;
            vscode.enable = true;
            cursor.enable = true;
            languageServers.enable = true;
            nodeTooling.enable = true;
            zoxide.replaceCd = true;
            git.opinionatedDefaults.enable = true;
            zsh = {
              personalAliases.enable = true;
              nodeWorkflow.enable = true;
              # workshop.zsh needs the nodeWorkflow helpers; nix/home/home.nix
              # asserts that, so enabling both here also exercises the assertion
              # against its satisfied case.
              workshop.enable = true;
            };
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
