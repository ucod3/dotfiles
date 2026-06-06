# Utility Functions

# Create npm/npx/yarn wrapper scripts in ~/.local/bin
if [ ! -f "$HOME/.local/bin/npm" ]; then
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/npm" << 'EOS'
#!/bin/sh
exec pnpm "$@"
EOS
  chmod +x "$HOME/.local/bin/npm"

  cat > "$HOME/.local/bin/npx" << 'EOS'
#!/bin/sh
exec pnpx "$@"
EOS
  chmod +x "$HOME/.local/bin/npx"

  cat > "$HOME/.local/bin/yarn" << 'EOS'
#!/bin/sh
exec pnpm "$@"
EOS
  chmod +x "$HOME/.local/bin/yarn"
fi

mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# Look up aliases - usage: aliases [search term]
# Examples:
#   aliases         → show all your custom aliases
#   aliases git     → show all git-related aliases
#   aliases pnpm    → show pnpm/npm aliases
aliases() {
  local search="${1:-}"
  local modules_dir="${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules"

  echo ""
  echo "── Your Aliases ─────────────────────────────"

  if [[ -n "$search" ]]; then
    echo "  (filtered: '$search')"
    echo ""
    grep -h "^alias" "$modules_dir"/*.zsh 2>/dev/null \
      | grep -i "$search" \
      | sed "s/^alias /  /" | sort
    echo ""
    echo "── All Active Aliases (filtered) ────────────"
    alias | grep -i "$search" | grep -v "^aliases\b" | sed "s/^/  /" | head -20
  else
    echo ""
    for f in "$modules_dir"/*.zsh; do
      local hits
      hits=$(grep "^alias" "$f" 2>/dev/null | sed "s/^alias /  /" | sort)
      if [[ -n "$hits" ]]; then
        echo "  ── $(basename "$f" .zsh) ──"
        echo "$hits"
        echo ""
      fi
    done
    echo "── Tip ──────────────────────────────────────"
    echo "  aliases git    → filter by keyword"
    echo "  alias          → show ALL aliases (including OMZ)"
    echo "  change         → edit your dotfiles"
  fi
  echo "─────────────────────────────────────────────"
  echo ""
}

real-npm() {
  echo "Using real npm directly (bypassing pnpm redirection)..."

  if ! command -v node >/dev/null 2>&1; then
    if [[ -x "/usr/local/bin/node" ]]; then
      NODE_PATH="/usr/local/bin/node"
    elif [[ -x "/opt/homebrew/bin/node" ]]; then
      NODE_PATH="/opt/homebrew/bin/node"
    elif [[ -x "/usr/bin/node" ]]; then
      NODE_PATH="/usr/bin/node"
    else
      echo "❌ Node.js not found. Please ensure Node.js is installed."
      return 1
    fi
  else
    NODE_PATH=$(command -v node)
  fi

  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npm through pnpm exec..."
    command pnpm exec npm "$@"
    return $?
  fi

  local npm_path=""
  for path in "/usr/local/bin/npm" "/opt/homebrew/bin/npm" "/usr/bin/npm"; do
    if [[ -x "$path" ]]; then
      npm_path="$path"
      break
    fi
  done

  if [[ -n "$npm_path" ]]; then
    echo "� Using npm from: $npm_path"
    "$npm_path" "$@"
    return $?
  fi

  local npm_cli
  npm_cli="$(command pnpm root -g 2>/dev/null)/npm/bin/npm-cli.js"
  if [[ -f "$npm_cli" ]]; then
    echo "📦 Using npm-cli.js with Node.js"
    "$NODE_PATH" "$npm_cli" "$@"
    return $?
  fi

  echo "❌ Failed to locate npm. Installing it with pnpm..."
  command pnpm add -g npm
  command pnpm exec npm "$@"
}

workshop-npx() {
  echo "Running npx command with original npm..."

  if ! command -v node >/dev/null 2>&1; then
    if [[ -x "/usr/local/bin/node" ]]; then
      NODE_PATH="/usr/local/bin/node"
    elif [[ -x "/opt/homebrew/bin/node" ]]; then
      NODE_PATH="/opt/homebrew/bin/node"
    elif [[ -x "/usr/bin/node" ]]; then
      NODE_PATH="/usr/bin/node"
    else
      echo "❌ Node.js not found. Please ensure Node.js is installed."
      return 1
    fi
  else
    NODE_PATH=$(command -v node)
  fi

  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npx through pnpm exec..."
    command pnpm exec npx "$@"
    return $?
  fi

  local npx_path=""
  for path in "/usr/local/bin/npx" "/opt/homebrew/bin/npx" "/usr/bin/npx"; do
    if [[ -x "$path" ]]; then
      npx_path="$path"
      break
    fi
  done

  if [[ -n "$npx_path" ]]; then
    echo "📦 Using npx from: $npx_path"
    "$npx_path" "$@"
    return $?
  fi

  echo "❌ Failed to locate npx. Installing npm with pnpm..."
  command pnpm add -g npm
  command pnpm exec npx "$@"
}

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