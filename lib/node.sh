#!/usr/bin/env bash
# lib/node.sh — shared Node.js path resolution helper
#
# Source this file from any script or zsh module:
#   source "$DOTFILES_ROOT/lib/node.sh"
#
# Provides:
#   _find_node
#     Resolves the path to the node binary.
#     Prints the absolute path to stdout and returns 0 on success.
#     Prints an error message to stderr and returns 1 if not found.
#
#   _find_npm_path
#     Resolves the path to a real (non-shim) npm binary in standard locations.
#     Prints the path to stdout and returns 0 on success, 1 if not found.
#
# Usage example:
#   source "$DOTFILES_ROOT/lib/node.sh"
#   node_bin=$(_find_node) || return 1
#   npm_bin=$(_find_npm_path)

_find_node() {
  # Prefer node already on PATH
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  # Fall back to standard macOS/Homebrew locations
  local candidate
  for candidate in /usr/local/bin/node /opt/homebrew/bin/node /usr/bin/node; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  echo "Node.js not found. Install it with: pnpm env use --global node@lts" >&2
  return 1
}

_find_npm_path() {
  local candidate
  for candidate in /usr/local/bin/npm /opt/homebrew/bin/npm /usr/bin/npm; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}
