---
trigger: always_on
---

# Global engineering rules

This file is **machine-global**: it is injected into every workspace on this
machine, in every session, before any task-specific context. Keep it short and
keep it repo-agnostic — anything specific to one project belongs in that
project's own files, not here (ADR-005, ADR-008).

## Workspace contract discovery

If the workspace contains an `AGENTS.md` at its root, read it first and treat it
as authoritative for that repo — layout, commands, hard rules, and definition of
done. It overrides anything here on conflict. Do not re-derive a project's rules
from this file when the project states them itself.

## Before you write

- **Blueprint first.** Present a short Markdown plan — what changes, in which
  files, and why alternatives were passed over — and wait for explicit approval
  before file-writing or running mutating commands.
- **Strict rollback.** If a change fails verification, revert to the last
  known-good commit before trying an alternative. Never stack fixes on a broken
  state.
- **Three strikes.** After 3 consecutive failed attempts at the same error,
  STOP. Print what you ran, what you actually observed, what you believe the
  root blocker is, and options for human intervention. Do not guess a 4th time.
- **Token cost is real.** Prefer small isolated checks (`bash -n`, dry-runs,
  single tests) over broad unvalidated builds.

## Cross-boundary routing

When you hit environmental friction mid-task, fix it in the right layer instead
of making the user switch context:

- **Global toolchain** — shell function syntax, package-manager API
  deprecations, system paths, global aliases, core packages. Patch the
  authoritative file in the `dotfiles` repo and rebuild the machine baseline.
  Do not write a local hack inside the project workspace.
- **Local workspace** — project env flags, ports, credentials, per-project
  runtime bypasses. Keep these out of the dotfiles entirely; put them in the
  project's `.envrc` and run `direnv allow`. The global `dotenv-init` helper
  scaffolds the common patterns.
