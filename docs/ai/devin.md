# Devin / Windsurf setup

The agent contract itself is vendor-neutral and lives in [`AGENTS.md`](../../AGENTS.md).
This page only covers wiring Devin and Windsurf up to it on a machine.

## What this repo tracks

| Path | Scope | Purpose |
|---|---|---|
| `.devin/rules/` | this repo | Pointer to `AGENTS.md` + the one Devin-specific rule |
| `.devin/skills/` | this repo | On-demand procedures (`loop-preventer`, `verify-and-audit`) |
| `.devin/workflows/` | this repo | Reusable prompts, e.g. `review.md` |
| `config/devin/hooks.json` | global | `PostToolUse` auto-**stage** hook (ADR-003, amended by ADR-008) |
| `config/devin/mcp/mcp_config.json` | global | MCP servers |
| `config/devin/skills/` | global | Cross-workspace skills |
| `config/windsurf/global_rules.md` | global | Machine-wide rules — repo-agnostic only |

Repo-local config under `.devin/` applies automatically when the repo is open.
Nothing to install.

## Global config

The two files Home Manager owns are linked declaratively, gated behind
`ai.enable = true` in `.local/settings.nix`:

```
~/.config/devin/config.json     -> config/devin/hooks.json
~/.config/windsurf/config.json  -> config/windsurf/config.json
```

Run `dot rebuild` after setting `ai.enable`. Do not create these symlinks by
hand — an imperative installer that claimed the same paths was removed in
ADR-008 precisely because two owners fought over one target.

The remaining Windsurf/Codeium paths are not managed by Nix, because Windsurf
rewrites them itself. Link them once:

```bash
mkdir -p ~/.codeium/windsurf/memories
ln -sf ~/dotfiles/config/windsurf/global_rules.md ~/.codeium/windsurf/memories/global_rules.md
ln -sf ~/dotfiles/config/devin/mcp/mcp_config.json ~/.codeium/windsurf/mcp_config.json
```

## Rules of the road

- `config/windsurf/global_rules.md` is injected into **every** workspace on the
  machine. Keep it repo-agnostic and short (ADR-005). Project-specific guidance
  belongs in that project's `AGENTS.md`.
- Never restate `AGENTS.md` rules in a vendor file — cite them by number
  (`R4`). See ADR-008 for what that duplication cost last time.
- Anything under `.devin/` must be committed. `dot validate` fails on untracked
  agent config, because an untracked rule silently does not apply elsewhere.
