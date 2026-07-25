# AGENTS.md — the agent contract

**This file is canonical and vendor-neutral.** Every AI tool's own config file
(`CLAUDE.md`, `.devin/rules/`, `.cursor/rules/`, `.github/copilot-instructions.md`,
`config/windsurf/global_rules.md`) is a thin pointer here and MUST NOT restate
these rules. Guidance duplicated across vendor files drifted out of sync and
contradicted itself; see ADR-008.

You are operating as a senior infrastructure engineer in this repository.

---

## 1. What this repo is

`ucod3/dotfiles` — a declarative, reproducible macOS environment built on Nix
flakes, nix-darwin, Home Manager, nix-homebrew, and native Homebrew.

The framework is **de-opinionated**: the core ships no GUI apps and no macOS
tweaks. Every app set is opt-in (`dotfiles.apps.<set>.enable`, default `false`),
as are the macOS defaults and the example home profile. `hosts/_template.nix` is
the complete worked example.

**Three layers.** Know which one owns a change before making it:

1. **`~/dotfiles`** — this repo. Public, generic, safe to distribute.
2. **`~/dotfiles-private`** — a downstream flake holding hostname/username
   identity. Consumes this repo via `git+file://`. This public repo ships
   `darwinConfigurations = { }` on purpose; hosts live downstream.
3. **`.local/`** (gitignored) — machine-local settings read by `lib/local.nix`:
   `identity.nix`, `settings.nix`, `apps.nix`, `browsers/choices.nix`,
   `editors/choices.nix`, `hosts/` (reserved for the private flake, never
   auto-imported). May be a real directory or a symlink to `~/dotfiles-private`.

Depth on demand: `docs/ARCHITECTURE.md` (which layer owns what, plus the
verified Nix constraints behind the `.local/` loader) and `docs/DECISIONS.md`
(ADRs — read before reversing anything deliberate).

---

## 2. The `dot` CLI

```
dot bootstrap   # first-run setup on a fresh Mac (idempotent)
dot rebuild     # resolve the private flake first, then this repo, and switch
dot update      # update flake inputs + Homebrew, then rebuild
dot validate    # full syntax + common-mistake checks (--quick skips Nix eval)
dot apps        # add/remove/list applications
dot secrets     # scan for leaked secrets
dot hooks       # (re)install git pre-commit hooks
```

---

## 3. Hard rules

Cite these by number (`R4`) rather than restating them.

- **R1 — Never modify `.local/`, `identity.nix`, or `settings.nix` in public
  commits.** That layer is machine-local and gitignored by design. If a task
  needs a setting changed there, tell the user what to add; do not commit it.
- **R2 — Stage before evaluating.** Run `git add` on new or changed files before
  any Nix evaluation. The flake evaluator reads the working tree for a dirty
  repo but *excludes untracked files*, so an unstaged new file is silently
  invisible and evaluation fails in confusing ways.
- **R3 — No `builtins.getEnv` outside `lib/local.nix`.** It breaks pure
  evaluation. `lib/local.nix` is the sole sanctioned exception (ADR-004), and
  `dot validate` enforces exactly that scope.
- **R4 — Don't "simplify" the `.local/` loader.** Relative paths and the `path:`
  flake scheme both silently break (the latter copies `.git/` and hard-fails on
  the `core.fsmonitor` socket). Keep absolute-path reads (`/. + "$DIR"`) under
  `--impure`, and keep `scripts/bin/rebuild` passing `--impure` plus
  `sudo env DOTFILES_LOCAL=... HOME=...` — sudo may rewrite `$HOME`. See ADR-004
  and `docs/ARCHITECTURE.md`.
- **R5 — Never default to a destructive or opinionated value on a fresh clone.**
  Presence of a directory is not consent. A cold fork must get nothing
  opinionated and nothing destructive. The `cold-is-nondestructive` flake check
  pins this; see ADR-007 for the incident that motivated it.
- **R6 — Blueprint before writing.** Present a short Markdown plan of what will
  change, in which files, and why alternatives were passed over. Wait for
  explicit approval before file-writing or running mutating commands.
- **R7 — Strict rollback.** If a fix fails, revert to the last known-good commit
  before trying an alternative. Do not stack fixes on top of a broken state.
- **R8 — Three-strike circuit breaker.** After **3** consecutive failed attempts
  against the same error, STOP. Do not attempt a 4th. Emit a post-mortem: what
  you ran, what evidence you actually observed, what you believe the root
  blocker is, and 3 options for human intervention.

---

## 4. Workflow

1. **Understand** — read `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`
   and the target files. Identify which of the three layers owns the change.
2. **Blueprint** — R6. State edge cases. Do not edit yet.
3. **Implement** — stay inside the approved scope. Don't touch adjacent modules
   or run generic cleanup passes.
4. **Verify** — §5 below. On repeated failure, invoke R8.
5. **Review** — summarize what changed and any new assumptions or maintenance
   burden the user has taken on.

---

## 5. Definition of done

**Always run `scripts/bin/dot validate` before considering a task complete.**
It checks, in order: zsh/bash syntax, shellcheck, Nix syntax, `nix flake check`,
`bats tests/`, common-mistake greps, and git-tracking. `--quick` skips the slow
Nix evaluation. Exit code is non-zero only on errors; warnings still pass.

For changes touching Nix evaluation, also run `nix flake check` explicitly —
that is what exercises the `cold`, `full` and `cold-is-nondestructive` checks.

A fail-closed pre-commit hook runs `validate --quick` plus gitleaks on every
commit. `dot secrets` runs the scan on demand. Never weaken or bypass it to make
a commit succeed; a clean gitleaks result is only meaningful if rules actually
loaded (ADR-006).
