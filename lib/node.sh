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

# Standard macOS/Homebrew locations searched when node is not on PATH, one per
# line. Split out as its own function purely to give tests a seam: these are
# absolute paths, so no amount of PATH isolation can hide a node that a CI
# runner image installed at /usr/local/bin/node. Tests override this function
# to simulate a machine with no node at all.
#
# Emitted as lines rather than an array or a space-separated string because
# this file is also sourced from zsh (config/zsh/modules/npm-compat.zsh), where
# unquoted parameter expansion does not word-split by default.
_node_fallback_paths() {
  echo /usr/local/bin/node
  echo /opt/homebrew/bin/node
  echo /usr/bin/node
}

_find_node() {
  # Prefer node already on PATH
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  # Fall back to standard macOS/Homebrew locations
  local candidate candidates
  candidates="$(_node_fallback_paths)"
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done <<< "$candidates"

  echo "Node.js not found. Install it with: pnpm runtime set node lts -g" >&2
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
