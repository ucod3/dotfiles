# npm-compat.zsh — npm/npx compatibility wrappers for pnpm-first environments
# Part of: config/zsh/modules/
#
# Provides:
#   real-npm          — bypass pnpm alias and run real npm directly
#   workshop-npx      — bypass pnpx alias and run real npx directly
#   setup-pnpm-workspace — auto-generate pnpm-workspace.yaml from package.json

# Shared node-path resolution (sources lib/node.sh from DOTFILES_ROOT)
_npm_compat_find_node() {
  local dotfiles="${DOTFILES_ROOT:-$HOME/dotfiles}"
  if [[ -f "$dotfiles/lib/node.sh" ]]; then
    # shellcheck source=../../../lib/node.sh
    source "$dotfiles/lib/node.sh"
    _find_node
  else
    # Inline fallback if lib is unavailable (should not happen after install)
    command -v node 2>/dev/null \
      || { echo "Node.js not found. Run: pnpm env use --global node@lts" >&2; return 1; }
  fi
}

# real-npm — use the real npm binary, bypassing the pnpm alias
real-npm() {
  echo "Using real npm directly (bypassing pnpm redirection)..."

  # pnpm exec is the safest route when pnpm is present
  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npm through pnpm exec..."
    command pnpm exec npm "$@"
    return $?
  fi

  # Try to find a real npm binary in standard locations
  local npm_bin
  npm_bin=$(
    for p in /usr/local/bin/npm /opt/homebrew/bin/npm /usr/bin/npm; do
      [[ -x "$p" ]] && echo "$p" && break
    done
  )

  if [[ -n "$npm_bin" ]]; then
    echo "📦 Using npm from: $npm_bin"
    "$npm_bin" "$@"
    return $?
  fi

  # Last resort: find node, then use pnpm's npm-cli.js
  local node_bin
  node_bin=$(_npm_compat_find_node) || return 1

  local npm_cli
  npm_cli="$(command pnpm root -g 2>/dev/null)/npm/bin/npm-cli.js"
  if [[ -f "$npm_cli" ]]; then
    echo "📦 Using npm-cli.js with Node.js"
    "$node_bin" "$npm_cli" "$@"
    return $?
  fi

  echo "❌ Failed to locate npm. Installing it with pnpm..."
  command pnpm add -g npm
  command pnpm exec npm "$@"
}

# workshop-npx — use the real npx binary, bypassing the pnpx alias
workshop-npx() {
  echo "Running npx command with original npm..."

  # pnpm exec is the safest route when pnpm is present
  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npx through pnpm exec..."
    command pnpm exec npx "$@"
    return $?
  fi

  # Try to find a real npx binary in standard locations
  local npx_bin
  npx_bin=$(
    for p in /usr/local/bin/npx /opt/homebrew/bin/npx /usr/bin/npx; do
      [[ -x "$p" ]] && echo "$p" && break
    done
  )

  if [[ -n "$npx_bin" ]]; then
    echo "📦 Using npx from: $npx_bin"
    "$npx_bin" "$@"
    return $?
  fi

  echo "❌ Failed to locate npx. Installing npm with pnpm..."
  command pnpm add -g npm
  command pnpm exec npx "$@"
}

# setup-pnpm-workspace — auto-generate pnpm-workspace.yaml from npm workspaces
setup-pnpm-workspace() {
  if [[ -f "./package.json" ]] && grep -q '"workspaces":' "./package.json" && [[ ! -f "./pnpm-workspace.yaml" ]]; then
    echo "Creating pnpm-workspace.yaml for npm workspace compatibility..."

    local workspace_patterns
    workspace_patterns=$(grep -A 20 '"workspaces":' "./package.json" | grep -m 1 -A 10 '\[' | grep -B 10 '\]' | grep -o '"[^"]*"' | sed 's/"//g' | grep -v '^\s*$')
    workspace_patterns=$(echo "$workspace_patterns" | grep -v "^\[" | grep -v "^\]")

    echo "packages:" > pnpm-workspace.yaml
    echo "$workspace_patterns" | while read -r pattern; do
      if [[ -n "$pattern" ]]; then
        echo "  - '$pattern'" >> pnpm-workspace.yaml
      fi
    done

    echo "Created pnpm-workspace.yaml with the following patterns:"
    cat pnpm-workspace.yaml
  fi
}
