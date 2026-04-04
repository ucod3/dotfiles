#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"

if ! command -v darwin-rebuild >/dev/null 2>&1; then
  echo "darwin-rebuild is not in PATH yet. Install Nix and nix-darwin first, then rerun this script."
  exit 1
fi

exec "$DOTFILES_ROOT/scripts/bin/rebuild"
