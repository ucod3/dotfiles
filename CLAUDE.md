# CLAUDE.md — Agent Entry Point

Keep this file lean (< 100 lines). It is loaded into every session, so it
carries only what an agent needs before touching anything. Depth lives in
`AGENTS.md` and `docs/` — read those on demand (ADR-005).

## What this is

`ucod3/dotfiles` — a declarative, reproducible macOS environment built on Nix
flakes, nix-darwin, Home Manager, nix-homebrew, and native Homebrew.

The framework is de-opinionated: every app set is opt-in
(`dotfiles.apps.<set>.enable`, default `false`). One example profile lives in
the module defaults plus `hosts/_template.nix`.

## Three layers

1. `~/dotfiles` — this repo. Public, generic, safe to distribute.
2. `~/dotfiles-private` — downstream flake holding hostname/username identity;
   consumes this repo via `git+file://`.
3. `.local/` (gitignored) — machine-local settings read by `lib/local.nix`:
   `identity.nix`, `settings.nix`, `browsers/choices.nix`,
   `editors/choices.nix`, `hosts/` (reserved for the private flake). May be a
   plain directory or a symlink to `~/dotfiles-private`.

## CLI

```
dot rebuild     # resolves the private flake first, then this repo
dot update      # update flake inputs + Homebrew, then rebuild
dot validate    # full syntax + common-mistake checks (--quick skips Nix eval)
dot help        # remaining subcommands: apps, secrets, hooks
```

## How to validate

Run `scripts/bin/dot validate` from the repo root. It checks, in order:

- Zsh syntax (`zsh -n`) and Bash syntax (`bash -n`)
- `shellcheck` on shell scripts
- Nix syntax, then `nix flake check`
- `bats tests/`
- Common-mistake greps (see below) and git-tracking checks

`--quick` skips the slow Nix evaluation. The full run takes a few minutes.
Exit code is non-zero only on errors; warnings still pass.

## Agent rules

- **Never** modify `.local/`, `identity.nix`, or `settings.nix` in public
  commits. That layer is machine-local and gitignored by design.
- **Stage before evaluating.** Run `git add` on new or changed files before any
  Nix evaluation — the flake evaluator silently ignores untracked files.
- **No `builtins.getEnv` outside `lib/local.nix`.** It breaks pure evaluation;
  `validate` fails the build on it. `lib/local.nix` is the sole sanctioned
  exception (ADR-004).
- **Don't "simplify" the `.local/` loader.** Relative paths and the `path:`
  flake scheme both silently break. Keep absolute-path reads (`/. + "$DIR"`)
  under `--impure`, and keep `scripts/bin/rebuild` passing `--impure` plus
  `sudo env DOTFILES_LOCAL=...` (sudo may rewrite `$HOME`). Rationale: ADR-004.
- **Keep this file lean.** New guidance belongs in `docs/` or `AGENTS.md`, not
  here, and not in `config/windsurf/global_rules.md` (ADR-005).
- **Always run `scripts/bin/dot validate`** before considering a task complete.

## Where to look next

- `AGENTS.md` — full system manifest and onboarding.
- `docs/ARCHITECTURE.md` — which layer owns which package or setting.
- `docs/DECISIONS.md` — ADRs; read before reversing anything deliberate.
- `docs/AI_WORKFLOW.md` — planning / implementation / loop-break protocol.
