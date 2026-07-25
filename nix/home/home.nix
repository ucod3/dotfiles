# Home Manager configuration
#
# LAYERING (audit finding M2): this module used to apply an opinionated
# personal profile unconditionally — a specific VS Code *channel*, a specific
# terminal's config, the whole oh-my-zsh framework, and a personal language
# server set. That contradicts the framework's stated contract that "a fresh
# clone installs nothing opinionated", which nix/modules/apps/ already honours.
#
# So the taste-specific pieces now sit behind `dotfiles.home.*` toggles that
# follow the same pattern as nix/modules/apps/: default to the example profile
# when a `.local/` settings layer exists (you ran install.sh or linked a
# private flake), and default to off on a cold public fork.
#
# What stays UNGATED is the framework core: git config, the bundled Neovim
# config, fzf/zoxide, base zsh, the `dot` dispatcher, and the two tools
# `scripts/bin/validate` itself depends on (shellcheck, bats).
#
# CUSTOMIZE, from your private host file:
#   home-manager.users.<you>.dotfiles.home.ohMyZsh.enable = true;
#   home-manager.users.<you>.dotfiles.home.vscode.configDir = "Code";
# or via `.local/settings.nix` — see lib/local.nix for the schema.

{ config, pkgs, lib, ... }:

let
  # Gitignored local-settings layer (see lib/local.nix for constraints)
  dotfilesLocal = import ../../lib/local.nix;
  pkgsByName = import ../../lib/pkgs.nix;

  cfg = config.dotfiles.home;

  # Shared default for every opinionated set below: adopt the example profile
  # only on a machine that has actually opted into this framework.
  exampleProfile = dotfilesLocal.exists;
  exampleProfileText = lib.literalExpression "<true when a .local/ layer exists>";
in
{
  options.dotfiles.home = {
    ohMyZsh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = ''
          Install the oh-my-zsh framework, its theme and plugin set, and the
          `pygments` dependency omz's syntax helpers expect.

          Disabling this leaves a plain (still fully configured) zsh with
          completion, autosuggestions, syntax highlighting and history search.
        '';
      };

      theme = lib.mkOption {
        type = lib.types.str;
        default = "robbyrussell"; # CUSTOMIZE: example profile
        description = "oh-my-zsh theme name.";
      };

      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # CUSTOMIZE: example profile.
        # NOTE: `common-aliases` is deliberately absent — its global `P` alias
        # collides with omz_urlencode's -P flag in termsupport.zsh, producing
        # "omz_urlencode:5: command not found: pygmentize" at startup.
        default = [ "git" "vscode" "copypath" "copyfile" "you-should-use" ];
        description = "oh-my-zsh plugins to enable.";
      };
    };

    ghostty.enable = lib.mkOption {
      type = lib.types.bool;
      default = exampleProfile;
      defaultText = exampleProfileText;
      description = ''
        Link the bundled Ghostty terminal config to ~/.config/ghostty/config.
        Harmless if Ghostty is not installed, but it is one terminal's opinion.
      '';
    };

    vscode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = "Link the bundled VS Code settings.json.";
      };

      configDir = lib.mkOption {
        type = lib.types.str;
        # CUSTOMIZE: "Code" for stable, "VSCodium" for the FOSS build.
        default = "Code - Insiders";
        description = ''
          XDG config directory name for the VS Code variant to configure.
          The default targets the Insiders channel; stable users want "Code".
        '';
      };
    };

    languageServers = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = "Install the bundled language server set.";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # CUSTOMIZE: example profile — Nixpkgs attribute names
        default = [ "lua-language-server" "pyright" "typescript-language-server" ];
        description = "Nixpkgs attribute names installed when languageServers is enabled.";
      };
    };

    nodeTooling = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = ''
          Install the Node toolchain expected by config/zsh/modules/node.zsh
          and npm-compat.zsh.
        '';
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "pnpm" ]; # CUSTOMIZE: example profile
        description = "Nixpkgs attribute names installed when nodeTooling is enabled.";
      };
    };
  };

  config = {
    home.stateVersion = "24.05";
    xdg.enable = true;

    xdg.configFile = {
      # ── Framework core (always applied) ───────────────────────────────────
      "git/config".source = ../../config/git/config;
      "git/.gitignore".source = ../../config/git/.gitignore;

      "nvim" = {
        source = ../../config/nvim;
        recursive = true;
      };
    }
    // lib.optionalAttrs cfg.vscode.enable {
      "${cfg.vscode.configDir}/User/settings.json".source =
        ../../config/vscode/settings.json;
    }
    // lib.optionalAttrs cfg.ghostty.enable {
      "ghostty/config".source = ../../config/ghostty/config;
    }
    // lib.optionalAttrs (dotfilesLocal.identity != null) {
      # Git identity from the gitignored .local/identity.nix
      # ({ name = "..."; email = "..."; }) — pulled in by the [include]
      # directive at the top of config/git/config.
      "git/config-local".text = ''
        [user]
          name = ${dotfilesLocal.identity.name or ""}
          email = ${dotfilesLocal.identity.email or ""}
      '';
    }
    // lib.optionalAttrs dotfilesLocal.aiEnabled {
      # AI tooling configs — gated behind `.local/settings.nix` ai.enable
      # (see nix/modules/ai.nix for the system-level counterpart)
      "windsurf/config.json".source = ../../config/windsurf/config.json;
      # Same target as docs/setup-devin-global.sh (hooks.json -> devin config)
      "devin/config.json".source = ../../config/devin/hooks.json;
    };

    # oh-my-zsh custom plugin, only fetched when omz itself is enabled
    home.file = lib.optionalAttrs cfg.ohMyZsh.enable {
      ".oh-my-zsh/custom/plugins/you-should-use" = {
        source = pkgs.fetchFromGitHub {
          owner = "MichaelAquilina";
          repo = "zsh-you-should-use";
          # Pin to specific commit instead of mutable branch
          rev = "f13d38f7bd98231386ad2c950b6dfbf5784d9f0d";
          sha256 = "sha256-1ojmr9+Wg5+X5Dip4sKjP4IKKACMncPQDZ8RtYQSQ80=";
        };
      };
    } // {
      # Expose the dot dispatcher on PATH for non-interactive scripts
      ".local/bin/dot" = {
        source = ../../scripts/bin/dot;
        executable = true;
      };
    };

    programs.git = {
      enable = true;

      # Use "openpgp" instead if you actively sign commits with GPG.
      signing.format = null;
    };

    programs.neovim = {
      enable = true;
      withRuby = false;
      withPython3 = false;

      # Runtime dependencies for Telescope and other plugins
      extraPackages = with pkgs; [
        ripgrep # Required for Telescope live_grep
        fd      # Required for Telescope file finder
      ];
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd" "cd" ];
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;

      # Silence dotDir deprecation: absolute path equivalent to default
      dotDir = config.home.homeDirectory;

      oh-my-zsh = {
        enable = cfg.ohMyZsh.enable;
        plugins = cfg.ohMyZsh.plugins;
        theme = cfg.ohMyZsh.theme;
        custom = "$HOME/.oh-my-zsh/custom";
      };

      history = {
        path = "${config.xdg.cacheHome}/zsh/history";
        size = 100000;
        save = 20000;
        ignoreDups = true;
        expireDuplicatesFirst = true;
        ignoreSpace = true;
        share = false;
      };

      envExtra = builtins.readFile ../../config/zsh/.zshenv;
      profileExtra = builtins.readFile ../../config/zsh/.zprofile;
      initContent = builtins.readFile ../../config/zsh/custom.zsh;
    };

    home.packages =
      # Framework core: scripts/bin/validate hard-depends on both of these.
      [ pkgs.shellcheck pkgs.bats ]
      ++ lib.optional cfg.ohMyZsh.enable pkgs.python312Packages.pygments
      ++ lib.optionals cfg.languageServers.enable
        (pkgsByName pkgs "dotfiles.home.languageServers.packages" cfg.languageServers.packages)
      ++ lib.optionals cfg.nodeTooling.enable
        (pkgsByName pkgs "dotfiles.home.nodeTooling.packages" cfg.nodeTooling.packages);
  };
}
