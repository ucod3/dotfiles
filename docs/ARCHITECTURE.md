# System Architecture & Layer Governance

This document outlines the operational boundaries for each system management framework in this ecosystem. You must never cross-contaminate package layers.

## 🛠️ Layer Ownership Matrix

### 1. nix-darwin (`hosts/default.nix`)
- **Responsibility:** Global macOS system preferences, underlying system services, core developer utilities, and general terminal/shell initialization toggles.
- **Nix Target:** `system.defaults`, `environment.systemPackages`.

### 2. Home Manager (`nix/home/home.nix`)
- **Responsibility:** Isolated user-space configurations, explicit application settings (Neovim init files, custom Zsh plugin initializers), environment variables (`.zshenv`), paths, and user-space binaries.
- **Nix Target:** `home.packages`, `programs.zsh`, `xdg.configFile`.

### 3. Homebrew / nix-homebrew
- **Responsibility:** Graphical User Interface (GUI) `.app` bundles, closed-source dependencies, proprietary utilities, and Mac App Store (MAS) targets.
- **Target:** `homebrew.casks`, `homebrew.brews`, `homebrew.masApps`.

## 🔄 Package Allocation Flowchart
When adding software to the Mac, follow this exact prioritization tree:
1. Is it a standard command-line utility or cross-platform tool available in `nixpkgs`? → Add to **Home Manager `home.packages`**.
2. Is it a core system tool or macOS configuration modifier? → Add to **nix-darwin `environment.systemPackages`**.
3. Is it a GUI application (`.app`), a cask, or a tool requiring native Mac frameworks? → Add to **Homebrew `casks`**.

## 🛑 Common Anti-Patterns to Avoid
- **Duplicate Declarations:** Do not install a tool via Home Manager packages if it is already provisioned globally inside nix-darwin.
- **Hardcoded Home Directory Strings:** Never use explicit strings like `/Users/<you>/` in any framework module or Zsh configuration. Always parse dynamically using `$HOME` or `$DOTFILES_ROOT`.
- **Pure Evaluation Breaks:** Never introduce `builtins.getEnv` into a Nix module. `lib/local.nix` is the single sanctioned exception (ADR-004) and `dot validate` enforces exactly that scope — see below.

## 4. The `.local/` settings layer — verified Nix constraints

These were established by experiment, not inference. Do not "simplify" them away
(rule R4 in `AGENTS.md`); each bullet is a failure someone already hit.

Scope note: since ADR-009 the default `dot rebuild` builds a pinned published
revision, so the `git+file:` working-tree semantics below apply to
`dot rebuild --override-local` and to `nix flake check` in this repo. The
`--impure` / `sudo env` and content-based-detection rules apply to every build.

- **Gitignored files are invisible to `git+file:` flakes.** Relative reads like
  `builtins.pathExists ./.local/...` silently return `false`, because untracked
  files are excluded from the store copy used for evaluation. Note the
  distinction that matters day to day: a *dirty* tree's **staged** changes are
  visible; only **untracked** files are not. Hence R2, "stage before evaluating".
- **The `path:` scheme is NOT a safe workaround.** It copies `.git/` into the
  store and hard-fails on `.git/fsmonitor--daemon.ipc` (this repo sets
  `core.fsmonitor = true`). With `.local` as an out-of-tree symlink, pure `path:`
  evaluation still resolves to MISSING.
- **The working pattern** is an absolute-path read (`/. + "$DIR"`) under
  `--impure`. It is the only approach that works for BOTH a plain gitignored
  `.local/` directory and a `.local -> ~/dotfiles-private` symlink.
- **Execution flags:** `scripts/bin/rebuild` always passes `--impure` and exports
  `DOTFILES_LOCAL` explicitly through `sudo env`, because sudo may rewrite
  `$HOME`. `lib/local.nix` resolves `$DOTFILES_LOCAL` → `~/dotfiles/.local`,
  degrading to empty settings under pure evaluation so CI and cold clones stay
  green. Nothing in the loader throws.
- **Detection is content-based, not existence-based.** A directory counts as a
  settings layer only if it carries a recognized settings file (`settingsFiles`
  in `lib/local.nix`, mirrored by `has_settings_layer()` in `scripts/bin/rebuild`
  — keep the two in sync). `exists` gates nothing behavioural; modules read the
  explicit `homebrewCleanup` / `macosDefaults` / `homeProfile` accessors, where
  `null` means "unspecified" and the module supplies a safe default. See ADR-007.
- **`.local/hosts/`** is reserved for the private flake and must never be
  auto-imported by the loader (double-import conflicts).
- **`PACKAGE_SOURCE` convention:** `install.sh` maps menu options to
  `nix:<attr>` or `brew:cask:<name>` via a `case` lookup (macOS ships bash 3.2 —
  no associative arrays). Prefer Nixpkgs; fall back to casks for apps that are
  unfree or broken on darwin.
