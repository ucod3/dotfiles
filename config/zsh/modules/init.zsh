# Basic initialization for Zsh
# Creates necessary directories and helper functions

mkdir -p "$XDG_CACHE_HOME/zsh" "$XDG_DATA_HOME/zsh" 2>/dev/null || true

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Guarded: direnv is optional on a cold clone (it ships via nix-darwin, which
# has not run yet on a fresh machine). Unguarded, this errors on every startup.
cmd_exists direnv && eval "$(direnv hook zsh)"