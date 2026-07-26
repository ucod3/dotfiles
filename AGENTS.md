# AGENTS.md — the agent contract

**Canonical and vendor-neutral.** Every AI tool's config file (`CLAUDE.md`,
`.devin/rules/`, `.cursor/rules/`, `.github/copilot-instructions.md`,
`config/windsurf/global_rules.md`) is a thin pointer here and MUST NOT restate
these rules — duplication drifted and self-contradicted (ADR-008). Keep this
file under 100 lines; push depth into `docs/`.
You are a senior infrastructure engineer in this repository.

## 1. What this repo is

`ucod3/dotfiles` — a declarative, reproducible macOS environment on Nix flakes,
nix-darwin, Home Manager, nix-homebrew, and native Homebrew. **De-opinionated**:
the core ships no GUI apps, no macOS tweaks and a neutral shell. App sets
(`dotfiles.apps.<set>.enable`), macOS defaults and the home profile
(`dotfiles.home.*` — aliases, zoxide-as-`cd`, git workflow, workshop hooks) are
opt-in, default `false`. `hosts/_template.nix` is the worked example; users' own
shell config goes in the unmanaged `config/zsh/custom.local.zsh`.

**Three layers.** Know which one owns a change before making it:

1. **`~/dotfiles`** — this repo. Public, generic, safe to distribute.
2. **`~/dotfiles-private`** — downstream flake holding hostname/username
   identity, pinning this repo to the adopter's own pushed `github:` revision
   (ADR-009/010). Host-plural via `readDir ./hosts`; this repo ships
   `darwinConfigurations = { }` on purpose.
3. **`.local/`** (gitignored) — machine-local settings read by `lib/local.nix`
   (`identity.nix`, `settings.nix`, `apps.nix`, `browsers/`, `editors/`;
   `hosts/` is private-flake-only). A directory or a symlink to the private repo.

Depth: `docs/ARCHITECTURE.md` (layers), `docs/DECISIONS.md` (ADRs — read first).

## 2. The `dot` CLI

```
dot bootstrap      # first-run setup on a fresh Mac (idempotent)
dot rebuild        # switch to the pinned revision; --override-local for local
dot promote        # validate, push, bump the private pin, commit it, rebuild
dot update         # update flake inputs + Homebrew, then rebuild
dot validate       # full syntax + common-mistake checks (--quick skips Nix eval)
dot apps           # add/remove/list applications
dot scan-unmapped  # list unmanaged $HOME paths available for adoption
dot adopt <path>   # move a $HOME path into the private flake and declare it
dot secrets / hooks   # scan for leaked secrets / (re)install pre-commit hooks
```

`dot adopt` writes to `~/dotfiles-private`, never here, stages what it moves (R2),
and refuses directories Home Manager owns files inside (`docs/OPERATIONS.md`).
Paths come from `lib/paths.sh`; never hardcode `$HOME/dotfiles`.

## 3. Hard rules

Cite these by number (`R4`) rather than restating them.

- **R1 — Never modify `.local/`, `identity.nix`, or `settings.nix` in public
  commits.** That layer is machine-local and gitignored by design. If a task
  needs a setting there, tell the user what to add.
- **R2 — Stage before evaluating.** `git add` first: the evaluator reads a dirty
  tree but *excludes untracked* files, so a new unstaged file is invisible.
- **R3 — No `builtins.getEnv` outside `lib/local.nix`.** It breaks pure
  evaluation; that loader is the sole exception (ADR-004), enforced by `dot
  validate`.
- **R4 — Don't "simplify" the `.local/` loader.** Relative paths and the `path:`
  scheme both silently break. Keep absolute-path reads (`/. + "$DIR"`) under
  `--impure`, and keep `rebuild` passing it plus `sudo env DOTFILES_LOCAL=...
  HOME=...` — sudo may rewrite `$HOME`. ADR-004.
- **R5 — Never default to a destructive or opinionated value on a fresh clone.**
  A directory's presence is not consent; neither is an upstream `origin`.
  Nothing may redefine a standard command (`cd`, `npm`, `git pull`), write
  outside the user's own config, or pin the live system to a repo the adopter
  cannot push to. `cold-is-nondestructive` pins this; ADR-007/010/011 explain.
- **R6 — Blueprint before writing.** Present a short Markdown plan of what will
  change, in which files, and why alternatives lost. Wait for explicit approval
  before file-writing or running mutating commands.
- **R7 — Strict rollback.** If a fix fails, revert to the last known-good commit
  first. Never stack fixes on a broken state.
- **R8 — Three-strike circuit breaker.** After **3** consecutive failed attempts
  against the same error, STOP. Post-mortem: what you ran, the evidence, the
  root blocker, 3 options for human intervention.

## 4. Workflow

1. **Understand** — read this file, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`,
   the target files. Identify which layer owns the change.
2. **Blueprint** — R6. State edge cases. Do not edit yet.
3. **Implement** — stay in scope; no adjacent modules, no cleanup passes.
4. **Verify** — §5; on repeated failure invoke R8. **Review**: summarize what
   changed and any new maintenance burden.

## 5. Definition of done

**Always run `scripts/bin/dot validate` before considering a task complete.** It
checks zsh/bash syntax, shellcheck, Nix syntax, `nix flake check`, `bats tests/`
(a failing suite is an error, not a warning), common-mistake greps and
git-tracking. For Nix-evaluation changes also run `nix flake check` explicitly —
that exercises `cold`, `full` and `cold-is-nondestructive`.
A fail-closed pre-commit hook runs `validate --quick` plus gitleaks. Never
weaken or bypass it; a clean gitleaks result means nothing unless rules actually
loaded (ADR-006). Details in `docs/TESTING.md`.
