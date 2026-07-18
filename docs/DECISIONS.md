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
