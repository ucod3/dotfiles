# CLAUDE.md — AI Session Context

This file mirrors the agent-critical context from `AGENTS.md` so any AI
assistant auto-loads it. Read `AGENTS.md` for the full manifest.

## Architecture (three layers)
1. `~/dotfiles` — public, de-opinionated framework. Every app set is opt-in
   (`dotfiles.apps.<set>.enable`, default false). One example profile lives
   in the module defaults + `hosts/_template.nix`.
2. `~/dotfiles-private` — private flake holding hostname/username identity;
   consumes the public repo via `git+file://`.
3. `.local/` (gitignored) — machine-local settings read by `lib/local.nix`:
   `identity.nix`, `settings.nix`, `browsers/choices.nix`,
   `editors/choices.nix`, `hosts/` (reserved for the private flake). May be
   a plain directory or a symlink to `~/dotfiles-private`.

## Hard-won Nix quirks (empirically verified — do not regress)
- Gitignored paths are INVISIBLE to `git+file:` flake evaluation; relative
  `builtins.pathExists ./.local/...` silently returns false.
- `path:` scheme is unsafe here: copies `.git/` into the store and hard-fails
  on the `core.fsmonitor` socket; out-of-tree symlinks stay MISSING purely.
- Correct pattern: absolute-path reads (`/. + "$DIR"`) under `--impure`.
  `scripts/bin/rebuild` passes `--impure` and `sudo env DOTFILES_LOCAL=...`
  (sudo may rewrite `$HOME`). Pure eval degrades to empty settings (CI-safe).

## Conventions
- `PACKAGE_SOURCE` (install.sh): menu option → `nix:<attr>` or
  `brew:cask:<name>`; bash-3.2 `case` lookup, no associative arrays.
- `dotfiles.ai.enable` gates all AI tooling (Devin Desktop cask,
  Windsurf/Devin config symlinks).
- Stage files (`git add`) before any Nix evaluation — the flake evaluator
  silently ignores untracked files.
- Rebuild: `dot rebuild`. Validate: `dot validate`. Tests: `bats tests/`.
