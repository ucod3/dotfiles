# Node.js Management
# Uses pnpm as the primary package manager with on-demand Node.js installation
# This approach saves disk space: no global Node.js, no duplicate node_modules
#
# Initial Setup:
#   pnpm comes pre-installed via Nix (no Node.js installed initially)
#   When you first run pnpm, it will auto-install Node.js LTS
#
# Commands:
#   pnpm-use-node 18     - Install and use Node.js 18 globally via pnpm
#   pnpm runtime set node 20 -g  - Install Node.js 20 (pnpm 11+)
#   ensure-node 18       - Ensure Node.js 18 is available (auto-installs if needed)
#
# Why this approach?
#   - No need to download node_modules 100 times for 100 projects
#   - pnpm's content-addressable store shares packages across projects
#   - Node.js versions managed by pnpm, not system package manager
#   - Saves significant disk space compared to npm/yarn

# Ensure PNPM_HOME/bin is in PATH (idempotent — safe to re-source)
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# Install a Node.js version via pnpm (pnpm 11+ API)
_pnpm_install_node() {
  local version="$1"
  command pnpm runtime set node "$version" -g
  hash -r 2>/dev/null || true
}

# NVM Configuration (only loaded on demand - fallback if needed)
nvm-init() {
  echo "Loading NVM..."

  if [ ! -e "$NVM_DIR/nvm.sh" ] && cmd_exists brew && [ -f "$(brew --prefix 2>/dev/null)/opt/nvm/nvm.sh" ]; then
    mkdir -p "$NVM_DIR" 2>/dev/null || true
    ln -sf "$(brew --prefix)/opt/nvm/nvm.sh" "$NVM_DIR/nvm.sh" 2>/dev/null || true
    ln -sf "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" "$NVM_DIR/bash_completion" 2>/dev/null || true
  fi

  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

  echo "NVM loaded successfully"
}

pnpm-use-node() {
  local version=$1
  if [ -z "$version" ]; then
    echo "Usage: pnpm-use-node <version>"
    echo "Example: pnpm-use-node 18"
    return 1
  fi

  echo "Setting up Node.js $version using pnpm..."
  _pnpm_install_node "$version"
  echo "Node.js $(node -v) activated"
}

detect-node-version() {
  local package_json="$1"
  local default_version="lts"

  if [[ ! -f "$package_json" ]]; then
    echo "$default_version"
    return
  fi

  local node_version
  node_version=$(grep -o '"node": *"[^"]*"' "$package_json" 2>/dev/null | cut -d'"' -f4)

  if [[ -z "$node_version" ]]; then
    if grep -q '"epicshop"' "$package_json" 2>/dev/null; then
      if grep -q 'Node.* v\?1[0-9]' "$package_json"; then
        local detected
        detected=$(grep -o 'Node.* v\?[0-9]\{1,2\}' "$package_json" | grep -o '[0-9]\{1,2\}')
        if [[ -n "$detected" ]]; then
          echo "$detected"
          return
        fi
      fi
    fi
    echo "$default_version"
    return
  fi

  if [[ "$node_version" == ">="* ]]; then
    echo "$node_version" | grep -o '[0-9]\{1,2\}'
  elif [[ "$node_version" == "^"* || "$node_version" == "~"* ]]; then
    echo "$node_version" | grep -o '[0-9]\{1,2\}'
  else
    echo "$node_version"
  fi
}

ensure-node() {
  local required_version=${1:-""}
  local package_json=${2:-"./package.json"}

  if [[ -z "$required_version" && -f "$package_json" ]]; then
    required_version=$(detect-node-version "$package_json")
  fi

  if [[ -z "$required_version" ]]; then
    required_version="lts"
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "Node.js not found. Installing Node.js $required_version..."
    _pnpm_install_node "$required_version"

    if ! command -v node >/dev/null 2>&1; then
      echo "❌ Failed to install Node.js. Please install it manually with:"
      echo "pnpm runtime set node $required_version -g"
      return 1
    fi

    echo "✅ Node.js $(node -v) installed successfully"
    return 0
  fi

  if [[ "$required_version" != "lts" && "$required_version" != "latest" ]]; then
    local current_version
    current_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

    if [[ "$current_version" -lt "$required_version" ]]; then
      echo "⚠️ Current Node.js v$current_version is older than required v$required_version"
      echo "Installing Node.js $required_version..."
      _pnpm_install_node "$required_version"
      echo "✅ Node.js $(node -v) installed successfully"
    else
      echo "✅ Current Node.js $(node -v) meets requirements (v$required_version or newer)"
    fi
  else
    echo "✅ Using Node.js $(node -v)"
  fi

  return 0
}

pnpm() {
  # Pass through subcommands that manage pnpm itself or its runtime
  if [[ "$1" == "env" || "$1" == "runtime" || "$1" == "setup" ]]; then
    command pnpm "$@"
    return $?
  fi

  ensure-node && command pnpm "$@"
}

pnpx() {
  ensure-node && command pnpx "$@"
}

mkdir -p "$XDG_DATA_HOME/pnpm/global"
typeset -U PATH
