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
- **Hardcoded Home Directory Strings:** Never use explicit strings like `/Users/usmanbutt/` in any framework module or Zsh configuration. Always parse dynamically using `$HOME` or `$DOTFILES_ROOT`.
- **Pure Evaluation Breaks:** Never introduce `builtins.getEnv` directly inside a Nix module file. It completely breaks pure evaluation and flake reproducibility.
