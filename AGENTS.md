# AGENTS.md — the agent contract

**Canonical and vendor-neutral.** Every AI tool config is a thin pointer here and
MUST NOT restate these rules (ADR-008). Keep this file under 100 lines; push
depth into `docs/`. You are a senior infrastructure engineer in this repository.

## 1. What this repo is

Read `docs/PRODUCT.md` first. It is the product authority: a public, reusable
macOS framework paired with a private, user-owned profile that remains readable
and editable without AI. Architecture must serve that user journey, not replace
Nix with a second proprietary system.

**This project is maintenance-only.** It has no roadmap and no release gate. Do not
open speculative work, propose migrations, or expand scope; fix what is broken and
stop. Known gaps in `README.md` are limitations, not a backlog.

`ucod3/dotfiles` uses Nix flakes, nix-darwin, Home Manager, nix-homebrew, and
native Homebrew. The public core contains no user's identity, application choices,
adopted files, or personal preferences.

**Current layers.** Know which one owns a change before making it:

1. **`~/dotfiles`** — public framework, generic and safe to distribute.
2. **`~/dotfiles-private`** — private flake containing hosts, identity, personal
   configuration, adopted files, and the pinned public-framework revision.
3. **`.local/`** — compatibility bridge for machine-local settings read by
   `lib/local.nix`. It is load-bearing for existing installations and stays.

Depth: `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, and `docs/DECISIONS.md`.

## 2. The `dot` CLI

```
dot bootstrap      # first-run setup on a fresh Mac
dot rebuild        # switch to the pinned revision; --override-local for local
dot promote        # current framework/private publishing workflow
dot update         # update flake inputs + Homebrew, then rebuild
dot validate       # full checks; --quick skips Nix evaluation
dot apps           # add/remove/list applications
dot scan-unmapped  # list unmanaged $HOME paths
dot adopt <path>   # move a $HOME path into the private profile
dot secrets/hooks  # scan secrets / install pre-commit hooks
```

The CLI is a convenience and learning aid. New commands must reveal the files
and native Nix/Git operations they use rather than hiding a second system.
`dot adopt` writes to `~/dotfiles-private`, never here. Paths come from
`lib/paths.sh`; never hardcode `$HOME/dotfiles`.

## 3. Hard rules

Cite these by number (`R4`) rather than restating them.

- **R1 — Never commit private settings publicly.** Do not put usernames,
  hostnames, identity, application choices, adopted files, or personal settings
  in this repo. Tell the user which private file owns the change.
- **R2 — Stage before evaluating current `git+file:` paths.** Untracked files are
  invisible to Nix evaluation.
- **R3 — No `builtins.getEnv` outside `lib/local.nix`.** It is the sole current
  compatibility exception (ADR-004).
- **R4 — Do not alter the `.local/` loader.** It protects live installations and
  is not scheduled for replacement.
- **R5 — Safe and user-owned by default.** Nothing may delete software, rewrite
  standard commands, publish private data, or require a framework fork without
  explicit consent.
- **R6 — Blueprint before writing.** Present what will change, in which files,
  why, compatibility effects, and why alternatives lost. Wait for approval.
- **R7 — Strict rollback.** If a fix fails, return to the last known-good commit
  before trying another approach.
- **R8 — Three-strike circuit breaker.** After 3 consecutive failures against the
  same error, stop and report evidence, blocker, and human options.

## 4. Workflow

1. **Understand** — read this file, `docs/PRODUCT.md`, architecture, decisions,
   and target files. Identify public framework versus private-profile ownership.
2. **Blueprint** — R6.
3. **Implement** — stay in scope; preserve existing installations.
4. **Verify** — run relevant checks and review new complexity against the product
   contract. A green check does not replace a real install/update/restore journey.

Cross-participant work and unexpected findings follow
`docs/AI_COLLABORATION.md`. Interpret short task requests and resumable handoffs
through `docs/AI_TASK_PROTOCOL.md`; a chat-only finding is not durable.

## 5. Definition of done

Run `scripts/bin/dot validate` before considering a code task complete. It checks
shell and Nix syntax, `nix flake check`, bats, common mistakes, and git tracking.
For Nix-evaluation changes run `nix flake check` explicitly. Never weaken the
fail-closed secret checks. Details: `docs/TESTING.md`.
