# AGENTS.md — the agent contract

**Canonical and vendor-neutral.** Every AI tool's config file (`CLAUDE.md`,
`.devin/rules/`, `.cursor/rules/`, `.github/copilot-instructions.md`,
`config/windsurf/global_rules.md`) is a thin pointer here and MUST NOT restate
these rules — duplication drifted and self-contradicted (ADR-008). Keep this
file under 100 lines; push depth into `docs/`.

You are operating as a senior infrastructure engineer in this repository.

## 1. What this repo is

`ucod3/dotfiles` — a declarative, reproducible macOS environment on Nix flakes,
nix-darwin, Home Manager, nix-homebrew, and native Homebrew. It is
**de-opinionated**: the core ships no GUI apps and no macOS tweaks; app sets
(`dotfiles.apps.<set>.enable`), macOS defaults and the example home profile are
opt-in, default `false`. `hosts/_template.nix` is the worked example.

**Three layers.** Know which one owns a change before making it:

1. **`~/dotfiles`** — this repo. Public, generic, safe to distribute.
2. **`~/dotfiles-private`** — downstream flake holding hostname/username
   identity, consuming this repo via `git+file://`. This repo ships
   `darwinConfigurations = { }` on purpose; hosts live downstream.
3. **`.local/`** (gitignored) — machine-local settings read by `lib/local.nix`
   (`identity.nix`, `settings.nix`, `apps.nix`, `browsers/`, `editors/`;
   `hosts/` is private-flake-only and never auto-imported). May be a real
   directory or a symlink to `~/dotfiles-private`.

Depth: `docs/ARCHITECTURE.md` (package-layer ownership, verified Nix constraints
behind the `.local/` loader), `docs/DECISIONS.md` (ADRs — read before reversing
anything deliberate).

## 2. The `dot` CLI

```
dot bootstrap      # first-run setup on a fresh Mac (idempotent)
dot rebuild        # resolve the private flake, then this repo, and switch
dot update         # update flake inputs + Homebrew, then rebuild
dot validate       # full syntax + common-mistake checks (--quick skips Nix eval)
dot apps           # add/remove/list applications
dot scan-unmapped  # list unmanaged $HOME paths available for adoption
dot adopt <path>   # move a $HOME path into the private flake and declare it
dot secrets        # scan for leaked secrets
dot hooks          # (re)install git pre-commit hooks
```

`dot adopt` writes to `~/dotfiles-private`, never here, stages what it moves (R2),
and refuses any directory Home Manager owns files inside (`docs/OPERATIONS.md`).

## 3. Hard rules

Cite these by number (`R4`) rather than restating them.

- **R1 — Never modify `.local/`, `identity.nix`, or `settings.nix` in public
  commits.** That layer is machine-local and gitignored by design. If a task
  needs a setting there, tell the user what to add; do not commit it.
- **R2 — Stage before evaluating.** `git add` new or changed files first: the
  evaluator reads a dirty tree but *excludes untracked* files, so an unstaged
  new file is silently invisible and evaluation fails confusingly.
- **R3 — No `builtins.getEnv` outside `lib/local.nix`.** It breaks pure
  evaluation. `lib/local.nix` is the sole sanctioned exception (ADR-004);
  `dot validate` enforces exactly that scope.
- **R4 — Don't "simplify" the `.local/` loader.** Relative paths and the `path:`
  scheme both silently break. Keep absolute-path reads (`/. + "$DIR"`) under
  `--impure`, and keep `scripts/bin/rebuild` passing `--impure` plus `sudo env
  DOTFILES_LOCAL=... HOME=...` — sudo may rewrite `$HOME`. ADR-004.
- **R5 — Never default to a destructive or opinionated value on a fresh clone.**
  Presence of a directory is not consent. The `cold-is-nondestructive` flake
  check pins this; ADR-007 is the incident that motivated it.
- **R6 — Blueprint before writing.** Present a short Markdown plan of what will
  change, in which files, and why alternatives were passed over. Wait for
  explicit approval before file-writing or running mutating commands.
- **R7 — Strict rollback.** If a fix fails, revert to the last known-good commit
  before trying an alternative. Never stack fixes on a broken state.
- **R8 — Three-strike circuit breaker.** After **3** consecutive failed attempts
  against the same error, STOP. Emit a post-mortem: what you ran, what evidence
  you observed, the root blocker, and 3 options for human intervention.

## 4. Workflow

1. **Understand** — read this file, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`
   and the target files. Identify which of the three layers owns the change.
2. **Blueprint** — R6. State edge cases. Do not edit yet.
3. **Implement** — stay in scope; no adjacent modules, no cleanup passes.
4. **Verify** — §5. On repeated failure, invoke R8.
5. **Review** — summarize what changed and any new maintenance burden.

## 5. Definition of done

**Always run `scripts/bin/dot validate` before considering a task complete.** It
checks zsh/bash syntax, shellcheck, Nix syntax, `nix flake check`, `bats tests/`,
common-mistake greps, and git-tracking; non-zero exit on errors only. For changes
touching Nix evaluation also run `nix flake check` explicitly — that exercises
the `cold`, `full` and `cold-is-nondestructive` checks.

A fail-closed pre-commit hook runs `validate --quick` plus gitleaks. Never
weaken or bypass it to make a commit succeed; a clean gitleaks result means
nothing unless rules actually loaded (ADR-006). Details in `docs/TESTING.md`.
