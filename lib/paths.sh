#!/usr/bin/env bash
# lib/paths.sh — the single resolution point for this repo's three path variables
#
# Every script under scripts/bin/ used to open with its own
# `DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"`, which hardcoded the clone
# location in eight places, and `dot-adopt` read `DOTFILES_PRIVATE` while
# `rebuild`, `install.sh` and `setup-private-host` read `DOTFILES_PRIVATE_FLAKE`
# — two names for one directory, so setting the documented one had no effect on
# adoption. This file is the fix; source it and call the accessors.
#
# Sourcing prelude used by every caller (paths.sh must be found before
# DOTFILES_ROOT exists, so the caller locates it from its own directory):
#
#   _SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
#   _PATHS="${_SELF_DIR%/scripts/bin}/lib/paths.sh"
#   [[ -f "$_PATHS" ]] || _PATHS="${DOTFILES_ROOT:-$HOME/dotfiles}/lib/paths.sh"
#   source "$_PATHS"
#   DOTFILES_ROOT="$(dotfiles_root)"
#
# Accessors:
#   dotfiles_root        → this repo's checkout
#   private_flake_root   → the downstream private flake (~/dotfiles-private)
#   local_dir            → the gitignored .local/ settings layer
#   has_settings_layer   → whether that layer contains recognized settings

# ── The public framework checkout ────────────────────────────────────────────
# Resolution order:
#   1. $DOTFILES_ROOT              — explicit override always wins
#   2. the parent of this file     — makes a clone outside ~/dotfiles just work
#   3. $HOME/dotfiles              — last resort
#
# Step 2 is why this is a function rather than a constant: `${BASH_SOURCE[0]}`
# inside a sourced file names *this* file, so the repo can locate itself no
# matter where it was cloned. It is guarded on flake.nix actually being there,
# because `dot` is ALSO deployed as a /nix/store symlink at ~/.local/bin/dot,
# whose parent directory is not a checkout at all — that path falls through to 3.
dotfiles_root() {
  if [[ -n "${DOTFILES_ROOT:-}" ]]; then
    printf '%s\n' "$DOTFILES_ROOT"
    return 0
  fi

  local d
  d="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)" || d=""
  if [[ -n "$d" && -f "$d/flake.nix" ]]; then
    printf '%s\n' "$d"
    return 0
  fi

  printf '%s\n' "$HOME/dotfiles"
}

# ── The private downstream flake ─────────────────────────────────────────────
# DOTFILES_PRIVATE is the historical spelling used only by dot-adopt. It is
# still honoured so existing setups do not break, but it warns: two names for
# one path is how the two halves of adoption ended up pointing at different
# directories.
private_flake_root() {
  if [[ -n "${DOTFILES_PRIVATE_FLAKE:-}" ]]; then
    printf '%s\n' "$DOTFILES_PRIVATE_FLAKE"
    return 0
  fi

  if [[ -n "${DOTFILES_PRIVATE:-}" ]]; then
    if [[ -z "${_DOTFILES_PRIVATE_WARNED:-}" ]]; then
      _DOTFILES_PRIVATE_WARNED=1
      echo "note: DOTFILES_PRIVATE is deprecated — use DOTFILES_PRIVATE_FLAKE" >&2
    fi
    printf '%s\n' "$DOTFILES_PRIVATE"
    return 0
  fi

  printf '%s\n' "$HOME/dotfiles-private"
}

# ── The gitignored machine-local settings layer ──────────────────────────────
# Mirrors the resolution order in lib/local.nix: an explicit DOTFILES_LOCAL
# (which scripts/bin/rebuild exports across the sudo boundary, since sudo may
# rewrite $HOME) beats <repo>/.local. See ADR-004.
local_dir() {
  if [[ -n "${DOTFILES_LOCAL:-}" ]]; then
    printf '%s\n' "$DOTFILES_LOCAL"
    return 0
  fi

  printf '%s\n' "$(dotfiles_root)/.local"
}

# Presence is not consent (ADR-007). Keep this list exactly aligned with
# `settingsFiles` in lib/local.nix so shell preflight reports the same layer
# that Nix will actually load.
has_settings_layer() {
  local dir="$1"
  [[ -e "$dir/settings.nix" || -e "$dir/identity.nix" || -e "$dir/apps.nix" ]]
}
