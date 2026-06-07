---
trigger: always_on
---

# Core Engineering Guardrails

## 🧠 Architectural Philosophy
- Always prioritize environmental portability, structural modularity, and explicit safety guardrails.
- **Blueprint First:** Never write, patch, or modify code immediately upon receiving a high-level task. You must always provide a Markdown blueprint detailing your proposed changes first and wait for explicit user approval before switching to file-writing or terminal tools.

## ⚠️ Unbreakable Restrictions
- **Strict Rollback:** If you execute a script, validate a change, or trigger a Nix rebuild and it fails, you must immediately revert your file changes to the last known working Git commit before trying an alternative solution. Do not stack fixes on top of broken code.
- **Git & Nix Tree Awareness:** Always run `git add .` or explicitly stage new files before attempting a Nix evaluation or running a rebuild script, otherwise the Nix flake evaluator will silently ignore them. Furthermore, any changes you make to custom rules (`.devin/rules/`) or skills (`.devin/skills/`) MUST be staged and committed alongside your feature implementations. Never leave the `.devin/` directory dirty or untracked at the end of a task.
- **No Impurities:** Never introduce hardcoded local paths, username assumptions, or impure environment calls (`builtins.getEnv`). Everything must evaluate dynamically or be modularized per-host.