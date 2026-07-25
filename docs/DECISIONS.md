# Architectural Decision Records (ADR)

This log records long-term structural decisions, trade-offs, and design choices. Agents must consult this log to ensure they do not reverse deliberate choices.

## [ADR-001] Ghostty Installed via Homebrew Cask
- **Context:** Ghostty can be compiled or packaged via Nix experimental derivations, but its macOS integration requires strict application sandboxing and access to native rendering hooks.
- **Decision:** Ghostty is explicitly managed via the Homebrew Casks layer (`casks = [ "ghostty" ]`).
- **Consequence:** Do not attempt to refactor Ghostty into a standard `nixpkgs` entry.

## [ADR-002] Deprecated `vim.loop` Avoidance
- **Context:** Neovim 0.10+ deprecated the `vim.loop` API namespace in favor of the unified `vim.uv` module layer.
- **Decision:** All Lua config segments (`config/nvim/`) must leverage `vim.uv`. Legacy calls must integrate a fallback interlock check: `(vim.uv or vim.loop)`.
- **Consequence:** Any script rewrite introducing raw `vim.loop.` syntax will fail pre-commit hooks.

## [ADR-003] Downstream Flake Dynamic Syncing
- **Context:** Private infrastructure identifiers cannot leak to public remotes. The local `git+file://` architecture binds them, but ignores uncommitted files.
- **Decision:** A custom `PostToolUse` command hook automatically stages and auto-commits working adjustments.
- **Consequence:** Rebuilds are evaluated against local committed state (`HEAD`). Do not remove or decouple the auto-commit hook.

## [ADR-004] Impure `.local/` Settings Layer (Sanctioned `builtins.getEnv` Exception)
- **Context:** The gitignored `.local/` layer (machine identity + app selections) is invisible to pure `git+file:` evaluation (untracked files are excluded from the store copy). Empirical sandbox tests showed the `path:` scheme is unsafe: it copies `.git/` into the store, hard-fails on the `core.fsmonitor` daemon socket, and still resolves out-of-tree `.local -> ~/dotfiles-private` symlinks to MISSING under pure evaluation.
- **Decision:** `lib/local.nix` is the single sanctioned impure read point. It resolves `$DOTFILES_LOCAL` → `~/dotfiles/.local` → `~/dotfiles-private` via absolute paths (`/. + "$DIR"`), and `scripts/bin/rebuild` passes `--impure` plus `sudo env DOTFILES_LOCAL=... HOME=...` (sudo may rewrite `$HOME`). Under pure evaluation the loader degrades to empty settings so CI and cold clones evaluate green.
- **Consequence:** Do not add `builtins.getEnv` anywhere else (`validate` enforces this with a `lib/local.nix` exemption). Do not "simplify" the loader to relative paths or the `path:` scheme — both silently break. `.local/hosts/` is reserved for the private flake and must never be auto-imported by the loader (double-import conflicts).

## [ADR-005] Freeze on `global_rules.md` Expansion
- **Context:** `config/windsurf/global_rules.md` carries `trigger: always_on`, so its full contents are injected into every session regardless of task. It had grown to ~109 lines of five-phase enterprise governance — lifecycle classification, compliance matrices, a11y and SLA budgets — most of it irrelevant to any given change in this repo. Stacked on top of `AGENTS.md` and `docs/AI_WORKFLOW.md`, which restate much of the same protocol, the always-on preamble consumed a large share of the context window before the agent had read a single line of the actual diff, degrading attention on the work itself.
- **Decision:** Freeze `global_rules.md` at its current scope. New agent guidance goes into task-scoped locations instead: `docs/` for rationale and architecture, `.devin/skills/` for procedures invoked on demand, and root `CLAUDE.md` (hard cap: under 100 lines) for the always-loaded minimum. Adding a new section to `global_rules.md` requires a superseding ADR that justifies why the guidance must be always-on.
- **Consequence:** `CLAUDE.md` states what the repo is, how to validate, and the load-bearing agent rules, then points outward — progressive disclosure rather than inlining. Agents needing depth must read the linked document. Do not "helpfully" re-expand `global_rules.md` or copy `AGENTS.md` back into `CLAUDE.md`; that regrowth is exactly what this ADR exists to stop.

## [ADR-006] Auto-Commit Is Not a Safety Boundary in a Public Repo (supersedes part of ADR-003)
- **Context:** ADR-003 established a `PostToolUse` auto-commit hook (`config/devin/hooks.json`) that stages `AGENTS.md docs/ config/ nix/ hosts/ scripts/ lib/` and commits to `main` after every `exec` tool call, so that `git+file:` evaluation sees committed state. That decision was made when this repository was private. It is now public, and git history is permanent: anything the hook commits is published without human review. The 2026-07-25 public-purity audit found the compensating control was not merely weak but **absent** — `.gitleaks.toml` declared a `title` and an `[allowlist]` but no rules and no `[extend]` stanza, so gitleaks loaded an empty ruleset. A canary file containing a live-format AWS key, GitHub PAT and Slack token scanned completely clean through both `dot secrets` and the "mandatory, fail-closed" pre-commit hook. The hook could not fail. A blanket allowlist on the whole of `README.md` compounded it.
- **Decision:** Retain the auto-commit mechanism (ADR-003's evaluation constraint is real and unchanged), but stop treating it as reviewed output, and restore the control it depends on:
  1. `.gitleaks.toml` MUST carry `[extend] useDefault = true`. This is now the single most load-bearing line in the repository's secret hygiene; a config without it silently disables all scanning while still reporting success.
  2. Allowlist entries MUST be path-specific. No whole-file entries for documents that accept prose and code samples.
  3. Auto-commits are `wip:` checkpoints, not reviewed history. Squash or rewrite them before pushing to a public remote; never treat "the hook committed it" as evidence that content was vetted.
- **Consequence:** ADR-003 remains in force for the mechanism and must not be decoupled, but its implicit claim that pre-commit scanning makes auto-commit safe is withdrawn. Any future change to `.gitleaks.toml` must be validated against a canary containing known-format secrets — a passing scan proves nothing on its own, because the failure mode is a *clean* result. Treat "no leaks found" as meaningful only after confirming rules are actually loaded.
