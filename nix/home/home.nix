# Home Manager configuration
#
# LAYERING (audit finding M2): this module used to apply an opinionated
# personal profile unconditionally — a specific VS Code *channel*, a specific
# terminal's config, the whole oh-my-zsh framework, and a personal language
# server set. That contradicts the framework's stated contract that "a fresh
# clone installs nothing opinionated".
#
# So the taste-specific pieces now sit behind `dotfiles.home.*` toggles that
# default to the example profile when a `.local/` settings layer exists (you
# ran install.sh or linked a private flake), and default to off on a cold
# public fork.
#
# Applications themselves are not toggled at all any more: they come solely
# from the `casks` / `nixPackages` / `masApps` lists in `.local/settings.nix`.
# The per-category app-set modules this comment used to cite were deleted
# because their mkOption defaults hardcoded the author's own apps.
#
# A second pass (ADR-011) extended the same treatment to the shell itself,
# which was still imposing plenty: zoxide replacing `cd`, `epic-detect` writing
# .workshop.env into whatever repo you cd'd into, npm/yarn aliased to pnpm, and
# a global git config that forced Neovim and rebase-on-pull. Those now sit
# behind `dotfiles.home.zsh.*`, `dotfiles.home.zoxide.replaceCd` and
# `dotfiles.home.git.opinionatedDefaults`.
#
# What stays UNGATED is the framework core: the neutral half of the git config,
# the bundled Neovim config, fzf, zoxide (as `z`, not as `cd`), base zsh, the
# `dot` dispatcher and its aliases, and the two tools `scripts/bin/validate`
# itself depends on (shellcheck, bats).
#
# Whatever the toggles say, config/zsh/custom.local.zsh and ~/.zshrc.local are
# sourced last and are never managed — that is where your own aliases and tool
# setup belong.
#
# CUSTOMIZE, from your private host file:
#   home-manager.users.<you>.dotfiles.home.ohMyZsh.enable = true;
#   home-manager.users.<you>.dotfiles.home.vscode.configDir = "Code - Insiders";
# or via `.local/settings.nix` — see lib/local.nix for the schema.

{ config, pkgs, lib, ... }:

let
  # Gitignored local-settings layer (see lib/local.nix for constraints)
  dotfilesLocal = import ../../lib/local.nix;
  pkgsByName = import ../../lib/pkgs.nix;

  cfg = config.dotfiles.home;

  # Shared default for every opinionated set below. Opt-in only: having a
  # settings layer is not a request for this author's shell, editor and node
  # tooling — the user must ask for it explicitly (ADR-007).
  exampleProfile = dotfilesLocal.homeProfile != null && dotfilesLocal.homeProfile;
  exampleProfileText = lib.literalExpression ".local/settings.nix `home.exampleProfile.enable`, else false";

  # The zsh modules config/zsh/custom.zsh should source, in dependency order.
  # `init`, `utils`, `aliases` and `exports` are the neutral core: none of them
  # redefines a standard command or writes to the directory you are standing in.
  # The rest are gated (ADR-011). Order matters — aliases-personal references
  # helpers defined in node.zsh/npm-compat.zsh.
  zshModules =
    [ "init" ]
    ++ lib.optionals cfg.zsh.nodeWorkflow.enable [ "node" ]
    ++ [ "utils" ]
    ++ lib.optionals cfg.zsh.nodeWorkflow.enable [ "npm-compat" ]
    ++ [ "aliases" ]
    ++ lib.optionals cfg.zsh.personalAliases.enable [ "aliases-personal" ]
    ++ lib.optionals cfg.zsh.workshop.enable [ "workshop" ]
    ++ [ "exports" ];
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

    # NOTE: `vscode` and `cursor` toggles used to live here. They linked
    # config/vscode/settings.json — a file whose entire content was `{}` — over
    # ~/Library/Application Support/{Code,Cursor}/User/settings.json as a
    # read-only store symlink.
    #
    # That is destructive, not de-opinionated: enabling the example profile
    # replaced a real settings file with an empty object and then made it
    # unwritable, so the editor could not even put it back. Editor settings are
    # user content; the framework has none to offer. Version yours with:
    #
    #   dot adopt "~/Library/Application Support/Cursor/User/settings.json" --mutable
    #
    # which keeps the file writable, so the editor's own Settings UI still works
    # and every change lands in your private repo.

    # ── Shell composition ─────────────────────────────────────────────────────
    # config/zsh/custom.zsh is read verbatim into .zshrc and cannot see these
    # options, so the enabled set is passed to it as DOTFILES_ZSH_MODULES (see
    # programs.zsh.initContent below). Each toggle here adds one module name.
    zsh = {
      personalAliases.enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = ''
          Load config/zsh/modules/aliases-personal.zsh: ls shorthands,
          `grep --color`, `help` as `man`, and npm/yarn aliased to pnpm.

          Off by default because every entry redefines a command the system
          already provides. The `dot`/`rebuild`/`validate` aliases are NOT part
          of this — those are framework entry points and always load.
        '';
      };

      nodeWorkflow.enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = ''
          Load the pnpm-first Node modules (node.zsh, npm-compat.zsh): the
          `pnpm`/`pnpx` wrapper functions that auto-install a Node runtime, plus
          `ensure-node`, `real-npm` and `setup-pnpm-workspace`.

          Off by default: it makes `pnpm` a shell function that can install
          software as a side effect of running it.
        '';
      };

      workshop.enable = lib.mkOption {
        type = lib.types.bool;
        default = exampleProfile;
        defaultText = exampleProfileText;
        description = ''
          Load config/zsh/modules/workshop.zsh — the EpicWeb workshop helpers,
          including the `epic-detect` and `_detect_npm_project` chpwd hooks.

          Off by default, and the strongest case for gating in this file:
          `epic-detect` WRITES to the directory you just cd'd into. It creates
          .workshop.env and appends a line to that project's .gitignore, in any
          repository, without being asked. Requires nodeWorkflow for the
          helpers it calls.
        '';
      };
    };

    zoxide.replaceCd = lib.mkOption {
      type = lib.types.bool;
      default = exampleProfile;
      defaultText = exampleProfileText;
      description = ''
        Let zoxide take over the `cd` command (`zoxide init --cmd cd`).

        zoxide itself is framework core and always installed; this option is
        only about whether it shadows the shell builtin. Off by default because
        a `cd` that jumps to a frecency-ranked directory instead of the literal
        path is surprising in scripts and to anyone who did not ask for it.
        With this off, use `z` to jump.
      '';
    };

    git.opinionatedDefaults.enable = lib.mkOption {
      type = lib.types.bool;
      default = exampleProfile;
      defaultText = exampleProfileText;
      description = ''
        Link config/git/config-opinionated, which sets `core.editor = nvim`,
        `merge.tool = nvimdiff`, `pull.rebase = true`,
        `branch.autoSetupRebase = always`, `rebase.autoStash`, `push.default`,
        `commit.verbose` and `core.fsmonitor`.

        Off by default: these change what `git pull` and `git commit` do. The
        neutral part of the git config (identity include, excludesfile,
        `init.defaultBranch = main`, colour) always applies.
      '';
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

    # workshop.zsh calls real-npm, ensure-node and setup-pnpm-workspace, all of
    # which are defined in the nodeWorkflow modules. Enabling it alone produces
    # a shell whose chpwd hook fails with "command not found" on every cd into
    # a project — fail the evaluation instead of shipping that.
    assertions = [
      {
        assertion = cfg.zsh.workshop.enable -> cfg.zsh.nodeWorkflow.enable;
        message = ''
          dotfiles.home.zsh.workshop.enable requires
          dotfiles.home.zsh.nodeWorkflow.enable — workshop.zsh calls
          `real-npm`, `ensure-node` and `setup-pnpm-workspace`, which
          node.zsh and npm-compat.zsh define.
        '';
      }
    ];

    xdg.configFile = {
      # ── Framework core (always applied) ───────────────────────────────────
      "git/config".source = ../../config/git/config;
      "git/.gitignore".source = ../../config/git/.gitignore;

      "nvim" = {
        source = ../../config/nvim;
        recursive = true;
      };
    }
    // lib.optionalAttrs cfg.git.opinionatedDefaults.enable {
      # config/git/config includes this path unconditionally; git ignores a
      # missing include, so not writing it here IS the off switch.
      "git/config-opinionated".source = ../../config/git/config-opinionated;
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
      # Devin reads its hook definitions from config.json, so the repo's
      # hooks.json is the source for that path. Home Manager is the sole owner
      # of this symlink — an imperative installer script used to claim the same
      # target and clobber it (removed in ADR-008).
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
    }
    # ── Editors: native macOS paths, not XDG ────────────────────────────────
    # VS Code and its forks read ~/Library/Application Support/<variant>/User/
    # on macOS. They do NOT read $XDG_CONFIG_HOME — the `--user-data-dir` flag
    # is the only way to move them, and nothing here passes it. These mappings
    # used to go through xdg.configFile, so the file landed in
    # ~/.config/Code - Insiders/User/settings.json, which no editor has ever
    # read: the settings silently did nothing.
    // {
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
      # `--cmd cd` makes zoxide shadow the shell builtin. Framework core ships
      # zoxide but not that takeover — see dotfiles.home.zoxide.replaceCd.
      options = lib.optionals cfg.zoxide.replaceCd [ "--cmd" "cd" ];
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

      # custom.zsh is a plain file read verbatim into .zshrc, so it cannot read
      # Nix options. The enabled module list is handed to it as an environment
      # variable emitted immediately above it — mkBefore guarantees the export
      # lands first, which `home.sessionVariables` would not (those are sourced
      # from a profile file whose ordering relative to initContent is not ours
      # to depend on).
      initContent = lib.mkMerge [
        (lib.mkBefore ''
          export DOTFILES_ZSH_MODULES="${lib.concatStringsSep " " zshModules}"
        '')
        (builtins.readFile ../../config/zsh/custom.zsh)
      ];
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
