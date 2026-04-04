# Custom interactive Zsh logic sourced by Home Manager.
# Home Manager now loads Oh My Zsh, completion, autosuggestions,
# syntax highlighting, fzf, and zoxide. Keep only custom shell logic here.

mkdir -p "$XDG_CACHE_HOME/zsh" "$XDG_DATA_HOME/zsh" 2>/dev/null || true

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------- Node.js Management -------
# NVM Configuration (only loaded on demand)
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

  echo "Setting up Node.js $version using PNPM..."
  command pnpm env use --global node@"$version"
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
    command pnpm env use --global node@"$required_version"

    if ! command -v node >/dev/null 2>&1; then
      echo "❌ Failed to install Node.js. Please install it manually with:"
      echo "pnpm env use --global node@$required_version"
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
      command pnpm env use --global node@"$required_version"
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
  if [ "$1" = "env" ]; then
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
export npm_config_prefix="$HOME/.local"

# ------- Application Configurations -------
alias code="code-insiders"
alias npm="pnpm"
alias npx="pnpx"
alias yarn="pnpm"
alias pn=pnpm
alias update="source ~/.zshrc"
alias change="code-insiders $HOME/dotfiles/config/zsh/custom.zsh"
alias use-node="pnpm-use-node"
alias use-nvm="nvm-init && nvm use"
alias npm-real="real-npm"

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
    echo "📦 Using npm from: $npm_path"
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

workshop() {
  local cmd="$1"
  shift 1

  if [ "$cmd" = "help" ] || [ -z "$cmd" ]; then
    echo "Workshop Helper - Run workshops with proper npm compatibility"
    echo ""
    echo "Commands:"
    echo "  workshop setup      Install dependencies and run setup script with npm compatibility"
    echo "  workshop start      Run the workshop with npm compatibility"
    echo "  workshop run CMD    Run a specific npm script with npm compatibility"
    echo "  workshop npm CMD    Run a direct npm command with npm compatibility"
    echo "  workshop ex NUM     Run a specific exercise (EpicWeb format only)"
    return 0
  fi

  if [ ! -f "./package.json" ]; then
    echo "Error: No package.json found in current directory"
    return 1
  fi

  local is_epicweb=false
  if grep -q '"epicshop"' "./package.json"; then
    is_epicweb=true
    echo "🚀 EpicWeb workshop detected!"
  fi

  setup-pnpm-workspace

  case "$cmd" in
    setup)
      echo "📦 Setting up workshop with npm compatibility..."
      if $is_epicweb; then
        echo "Installing dependencies with pnpm first (faster)..."
        pnpm install
        echo "Running setup script with npm compatibility..."
        real-npm run setup
      else
        pnpm install
        real-npm run setup "$@"
      fi
      ;;
    start|dev)
      echo "🚀 Starting workshop with npm compatibility..."
      real-npm run "${cmd}" "$@"
      ;;
    ex|exercise)
      if ! $is_epicweb; then
        echo "Error: The 'ex' command is only available for EpicWeb workshops"
        return 1
      fi

      local ex_num="$1"
      if [ -z "$ex_num" ]; then
        echo "Error: Please provide an exercise number"
        echo "Usage: workshop ex <number>"
        return 1
      fi

      echo "🧩 Running exercise $ex_num..."
      local ex_dir
      ex_dir=$(find ./exercises -type d -name "*$ex_num.*problem*" | head -n 1)

      if [ -z "$ex_dir" ]; then
        echo "Error: Could not find exercise $ex_num"
        return 1
      fi

      echo "Found exercise at: $ex_dir"
      cd "$ex_dir" || return 1
      real-npm run dev
      ;;
    run)
      echo "▶️ Running npm script with compatibility: $*"
      real-npm run "$@"
      ;;
    npm)
      echo "🔄 Running npm command with compatibility: $*"
      real-npm "$@"
      ;;
    npx)
      echo "🔄 Running npx command with compatibility: $*"
      workshop-npx "$@"
      ;;
    *)
      echo "Unknown command: $cmd"
      workshop help
      return 1
      ;;
  esac
}

epic-start() {
  local repo_url="$1"
  local dir_name="$2"

  if [ -z "$repo_url" ]; then
    echo "Usage: epic-start <repository-url> [directory-name]"
    echo "Example: epic-start https://github.com/epicweb-dev/full-stack-foundations.git"
    return 1
  fi

  if [ -z "$dir_name" ]; then
    dir_name=$(basename "$repo_url" .git)
    echo "No directory name specified, using: $dir_name"
  fi

  echo "🔧 Ensuring basic Node.js is available..."
  ensure-node

  echo "🚀 Cloning repository..."
  git clone --depth 1 "$repo_url" "$dir_name"

  echo "📁 Navigating to project directory..."
  cd "$dir_name" || return 1

  echo "🔍 Detecting required Node.js version for this project..."
  ensure-node "" "./package.json"

  echo "⚙️ Setting up workshop..."
  setup-pnpm-workspace

  echo "Running npm setup script..."
  real-npm run setup

  echo "✅ Setup complete! Run 'workshop start' to begin the workshop."
}

epic-detect() {
  [[ -o interactive ]] || return

  if [[ -f "./package.json" ]] && grep -q '"epicshop"' "./package.json" 2>/dev/null; then
    if [[ "${EPIC_WORKSHOP_DETECTED:-false}" != "true" ]]; then
      echo "🚀 EpicWeb workshop detected! Setting up npm compatibility..."
      export EPIC_WORKSHOP_DETECTED="true"

      if [[ ! -f "./.workshop.env" ]]; then
        local detected_version
        detected_version=$(detect-node-version "./package.json")

        cat > ./.workshop.env << EOW
# Workshop environment configuration
# This file is used by epic-web workshops to maintain settings through git updates
# Add this file to .gitignore to prevent it from being committed

# Node version to use for this workshop
NODE_VERSION=$detected_version

# Compatibility mode (npm or pnpm)
PACKAGE_MANAGER=npm
EOW
        echo ".workshop.env" >> ./.gitignore 2>/dev/null
        echo "Created .workshop.env configuration file (added to .gitignore)"
      fi

      local node_version
      node_version=$(grep NODE_VERSION ./.workshop.env 2>/dev/null | cut -d= -f2)
      if [[ -n "$node_version" ]]; then
        echo "🔍 Setting up Node.js $node_version for this workshop..."
        ensure-node "$node_version"
      fi

      echo "Workshop compatibility mode active. Use 'workshop' commands for best compatibility."
      echo "Run 'workshop help' to see available commands."
    fi
  else
    export EPIC_WORKSHOP_DETECTED="false"
  fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd epic-detect
epic-detect

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
