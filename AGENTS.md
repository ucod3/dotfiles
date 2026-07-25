# Agent Onboarding Guide & System Manifest

Welcome. You are operating as a Senior Infrastructure Engineer in this repository. Before executing any code, file edits, or terminal scripts, you must orient yourself using this document.

## 🎯 Repository Intent
This repository is an AI-native, declarative, reproducible macOS development environment framework built utilizing Nix Flakes, nix-darwin, Home Manager, nix-homebrew, and native Homebrew. 

## 🗺️ Architectural Topology
We enforce a strict boundary separation between public framework code and private machine identities:
1. **Public Framework (`~/dotfiles`):** Contains generic system structures, configurations, custom shell modules, and AI workflows. Completely safe for public distribution. All opinionated app sets are OPT-IN (`enable = false` by default).
2. **Private Identity (`~/dotfiles-private`):** A downstream Git repository that handles machine hostnames (e.g., `<your-hostname>`), usernames (`<your-username>`), and private environment flags. Feeds dynamically from the public framework via a local `git+file://` flake input. Never substitute real values here — this file is public.
3. **Local Settings Layer (`~/dotfiles/.local/`, gitignored):** Machine-local identity and app selections read by `lib/local.nix`. May be a real directory (created interactively by `install.sh`) or a symlink to `~/dotfiles-private` (backing storage). Subfolders: `browsers/`, `editors/`, `hosts/` (reserved for the private flake — never auto-imported), plus `identity.nix` and `settings.nix`.

## 🧪 Local Settings Layer — Empirically Verified Nix Constraints
These were verified by sandbox experiments (do not "simplify" them away):
- **Gitignored files are invisible to `git+file:` flakes.** Relative reads like `builtins.pathExists ./.local/...` silently return `false` because untracked files are excluded from the store evaluation copy.
- **The `path:` scheme is NOT a safe workaround.** It copies `.git/` into the store and hard-fails on `.git/fsmonitor--daemon.ipc` (this repo sets `core.fsmonitor = true`). With `.local` as an out-of-tree symlink, pure `path:` evaluation still resolves to MISSING.
- **The working pattern:** absolute-path reads (`/. + "$DIR"`) under `--impure`. Works for BOTH a plain gitignored `.local/` directory and a `.local -> ~/dotfiles-private` symlink.
- **Execution flags:** `scripts/bin/rebuild` always passes `--impure` and exports `DOTFILES_LOCAL` explicitly through `sudo env` (sudo may rewrite `$HOME`). `lib/local.nix` resolves `$DOTFILES_LOCAL` → `~/dotfiles/.local` → `~/dotfiles-private`, degrading to empty settings under pure evaluation so CI/cold clones stay green.
- **`PACKAGE_SOURCE` convention:** `install.sh` maps menu options to `nix:<attr>` or `brew:cask:<name>` via a `case` lookup (macOS bash 3.2 — no associative arrays). Prefer Nixpkgs; fall back to casks for unfree/broken-on-darwin apps.
- **AI tooling gate:** `dotfiles.ai.enable` (default false, from `.local/settings.nix` `ai.enable`) gates the Devin Desktop cask (`nix/modules/ai.nix`) and Windsurf/Devin config symlinks (`nix/home/home.nix`).

## 📜 Mandatory Operational Runbook
You are strictly bound by the governance rules specified in our AI Contribution protocol. You must read the tracking documents before beginning your tasks:
- **System Topography:** Read `docs/ARCHITECTURE.md` to identify where variables and software packages belong.
- **Historical Context:** Read `docs/DECISIONS.md` to avoid re-introducing past failures or altering intentional exceptions.
- **Workflow Control:** Follow `docs/AI_WORKFLOW.md` explicitly to navigate Planning, Implementation, and Loop Break rules.
