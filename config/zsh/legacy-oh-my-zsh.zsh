# Zsh configuration file for Oh My Zsh


# Ensure required directories exist
mkdir -p "$XDG_CACHE_HOME/zsh" "$XDG_DATA_HOME/zsh" 2>/dev/null || true

# Safety function to handle command not found errors
cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ------- Theme & Plugins -------
ZSH_THEME="custom-cobalt2"
plugins=(
  git
  vscode
  copypath
  copyfile
  you-should-use
  common-aliases
)

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# ------- Node.js Management -------

# NVM Configuration (only loaded on demand)
# Function to enable NVM when needed
nvm-init() {
  echo "Loading NVM..."
  # Create symlinks for Homebrew's NVM to work with XDG structure
  if [ ! -e "$NVM_DIR/nvm.sh" ] && cmd_exists brew && [ -f "$(brew --prefix 2>/dev/null)/opt/nvm/nvm.sh" ]; then
    mkdir -p "$NVM_DIR" 2>/dev/null || true
    ln -sf "$(brew --prefix)/opt/nvm/nvm.sh" "$NVM_DIR/nvm.sh" 2>/dev/null || true
    ln -sf "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" "$NVM_DIR/bash_completion" 2>/dev/null || true
  fi

  # Load NVM script
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  # Load NVM bash completion
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

  echo "NVM loaded successfully"
}

# PNPM Node.js Version Management
# Use PNPM for Node version management
pnpm-use-node() {
  local version=$1
  if [ -z "$version" ]; then
    echo "Usage: pnpm-use-node <version>"
    echo "Example: pnpm-use-node 18"
    return 1
  fi

  echo "Setting up Node.js $version using PNPM..."
  command pnpm env use --global node@$version
  echo "Node.js $(node -v) activated"
}

# Improved Node.js detection and installation
detect-node-version() {
  local package_json="$1"
  local default_version="lts"

  # Check if package.json exists
  if [[ ! -f "$package_json" ]]; then
    echo "$default_version"
    return
  fi

  # Try to extract from engines field
  local node_version=$(grep -o '"node": *"[^"]*"' "$package_json" 2>/dev/null | cut -d'"' -f4)

  if [[ -z "$node_version" ]]; then
    # Check for EpicWeb workshops with specific Node version comments
    if grep -q '"epicshop"' "$package_json" 2>/dev/null; then
      # Try to find Node.js mentions in package.json comments or descriptions
      if grep -q 'Node.* v\?1[0-9]' "$package_json"; then
        # Extract version number (like 18 from Node.js v18)
        local detected=$(grep -o 'Node.* v\?[0-9]\{1,2\}' "$package_json" | grep -o '[0-9]\{1,2\}')
        if [[ -n "$detected" ]]; then
          echo "$detected"
          return
        fi
      fi
    fi
    echo "$default_version"
    return
  fi

  # Handle version ranges like ">=18"
  if [[ "$node_version" == ">="* ]]; then
    # Extract minimum version
    local min_version=$(echo "$node_version" | grep -o '[0-9]\{1,2\}')
    echo "$min_version"
  elif [[ "$node_version" == "^"* || "$node_version" == "~"* ]]; then
    # Extract base version for ^ or ~ ranges
    local base_version=$(echo "$node_version" | grep -o '[0-9]\{1,2\}')
    echo "$base_version"
  else
    # Direct version specification
    echo "$node_version"
  fi
}

# Improved ensure-node function to be more intelligent about required versions
ensure-node() {
  local required_version=${1:-""}
  local package_json=${2:-"./package.json"}

  # If no version specified, try to detect from package.json
  if [[ -z "$required_version" && -f "$package_json" ]]; then
    required_version=$(detect-node-version "$package_json")
  fi

  # If we still don't have a version, use latest LTS
  if [[ -z "$required_version" ]]; then
    required_version="lts"
  fi

  # Check if any Node.js is installed
  if ! command -v node >/dev/null 2>&1; then
    echo "Node.js not found. Installing Node.js $required_version..."
    command pnpm env use --global node@$required_version

    # Verify installation
    if ! command -v node >/dev/null 2>&1; then
      echo "❌ Failed to install Node.js. Please install it manually with:"
      echo "pnpm env use --global node@$required_version"
      return 1
    fi

    echo "✅ Node.js $(node -v) installed successfully"
    return 0
  fi

  # If specific version required, check if current version meets requirements
  if [[ "$required_version" != "lts" && "$required_version" != "latest" ]]; then
    local current_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

    if [[ "$current_version" -lt "$required_version" ]]; then
      echo "⚠️ Current Node.js v$current_version is older than required v$required_version"
      echo "Installing Node.js $required_version..."
      command pnpm env use --global node@$required_version
      echo "✅ Node.js $(node -v) installed successfully"
    else
      echo "✅ Current Node.js $(node -v) meets requirements (v$required_version or newer)"
    fi
  else
    echo "✅ Using Node.js $(node -v)"
  fi

  return 0
}

# Override pnpm command to ensure Node is available when needed
pnpm() {
  # For the env command, we need to use the built-in pnpm
  if [ "$1" = "env" ]; then
    command pnpm "$@"
    return $?
  fi

  # For other commands, ensure node is available first
  ensure-node && command pnpm "$@"
}

# Override pnpx command to ensure Node is available
pnpx() {
  ensure-node && command pnpx "$@"
}

# Alias to use a specific Node version
alias use-node="pnpm-use-node"
alias use-nvm="nvm-init && nvm use"

# Create directory for pnpm global installs
mkdir -p "$XDG_DATA_HOME/pnpm/global"

# Prevent duplicate PATH entries
typeset -U PATH

export npm_config_prefix="$HOME/.local"

# ------- Application Configurations -------
alias code="code-insiders"

# ------- Zoxide -------
eval "$(zoxide init --cmd cd zsh)"

# ------- FZF -------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ------- Aliases & Functions -------
# ------- npm to pnpm redirection -------
# Global npm command redirection
alias npm="pnpm"
alias npx="pnpx"
alias yarn="pnpm"
alias pn=pnpm
alias update="source $ZDOTDIR/.zshrc"
alias change="code-insiders $ZDOTDIR/.zshrc"

# Create shims for globally installed tools that might call npm directly
if [ ! -f "$HOME/.local/bin/npm" ]; then
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/npm" << 'EOF'
#!/bin/sh
exec pnpm "$@"
EOF
  chmod +x "$HOME/.local/bin/npm"

  cat > "$HOME/.local/bin/npx" << 'EOF'
#!/bin/sh
exec pnpx "$@"
EOF
  chmod +x "$HOME/.local/bin/npx"

  cat > "$HOME/.local/bin/yarn" << 'EOF'
#!/bin/sh
exec pnpm "$@"
EOF
  chmod +x "$HOME/.local/bin/yarn"

  echo "Created npm/npx/yarn shims in ~/.local/bin"
fi

mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# ------- npm compatibility functions -------
# Function to bypass pnpm redirection and use real npm when needed
real-npm() {
  echo "Using real npm directly (bypassing pnpm redirection)..."

  # Handle the case where node isn't in PATH inside the function
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

  # Use pnpm directly to run npm
  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npm through pnpm exec..."
    # The safest approach - use pnpm to execute npm
    command pnpm exec npm "$@"
    return $?
  fi

  # Fallback - try to find npm in standard locations
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

  # Look for npm-cli.js in PNPM global store
  local npm_cli="$(command pnpm root -g 2>/dev/null)/npm/bin/npm-cli.js"
  if [[ -f "$npm_cli" ]]; then
    echo "📦 Using npm-cli.js with Node.js"
    "$NODE_PATH" "$npm_cli" "$@"
    return $?
  fi

  echo "❌ Failed to locate npm. Installing it with pnpm..."
  command pnpm add -g npm

  # Try again after installation
  command pnpm exec npm "$@"
  return $?
}

# Similar update for workshop-npx
workshop-npx() {
  echo "Running npx command with original npm..."

  # Handle the case where node isn't in PATH
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

  # Use pnpm to execute npx
  if command -v pnpm >/dev/null 2>&1; then
    echo "📦 Using npx through pnpm exec..."
    command pnpm exec npx "$@"
    return $?
  fi

  # Fallback to system npx
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

  # Try again after installation
  command pnpm exec npx "$@"
  return $?
}

# Fix for pnpm workspace compatibility
setup-pnpm-workspace() {
  # Check if package.json has workspaces but no pnpm-workspace.yaml
  if [[ -f "./package.json" ]] && grep -q '"workspaces":' "./package.json" && [[ ! -f "./pnpm-workspace.yaml" ]]; then
    echo "Creating pnpm-workspace.yaml for npm workspace compatibility..."

    # Extract only the workspace patterns, not all JSON values
    local workspace_patterns=$(grep -A 20 '"workspaces":' "./package.json" | grep -m 1 -A 10 '\[' | grep -B 10 '\]' | grep -o '"[^"]*"' | sed 's/"//g' | grep -v '^\s*$')

    # Filter out non-pattern lines
    workspace_patterns=$(echo "$workspace_patterns" | grep -v "^\[" | grep -v "^\]")

    # Create pnpm-workspace.yaml
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

# Universal workshop handler - works with any workshop structure
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

  # Check for package.json
  if [ ! -f "./package.json" ]; then
    echo "Error: No package.json found in current directory"
    return 1
  fi

  # Detect if this is an EpicWeb workshop
  local is_epicweb=false
  if grep -q '"epicshop"' "./package.json"; then
    is_epicweb=true
    echo "🚀 EpicWeb workshop detected!"
  fi

  # Setup PNPM workspace compatibility first
  setup-pnpm-workspace

  case "$cmd" in
    setup)
      echo "📦 Setting up workshop with npm compatibility..."
      if $is_epicweb; then
        echo "Installing dependencies with pnpm first (faster)..."
        pnpm install
        echo "Running setup script with npm compatibility..."
        # Use real npm directly instead of with-real-npm
        real-npm run setup
      else
        pnpm install
        real-npm run setup "$@"
      fi
      ;;
    start|dev)
      echo "🚀 Starting workshop with npm compatibility..."
      # Use real npm directly
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
      # Find the exercise directory
      local ex_dir=$(find ./exercises -type d -name "*$ex_num.*problem*" | head -n 1)

      if [ -z "$ex_dir" ]; then
        echo "Error: Could not find exercise $ex_num"
        return 1
      fi

      echo "Found exercise at: $ex_dir"
      cd "$ex_dir" || return 1

      # Run the dev script with npm compatibility
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

# Alias for consistency
alias npm-real="real-npm"

# Example workflow for EpicWeb projects
epic-start() {
  local repo_url="$1"
  local dir_name="$2"

  if [ -z "$repo_url" ]; then
    echo "Usage: epic-start <repository-url> [directory-name]"
    echo "Example: epic-start https://github.com/epicweb-dev/full-stack-foundations.git"
    return 1
  fi

  # Extract directory name from repo URL if not provided
  if [ -z "$dir_name" ]; then
    # Extract the repository name from the URL
    dir_name=$(basename "$repo_url" .git)
    echo "No directory name specified, using: $dir_name"
  fi

  # Make sure we have Node.js installed first (detect version after clone)
  echo "🔧 Ensuring basic Node.js is available..."
  ensure-node

  echo "🚀 Cloning repository..."
  git clone --depth 1 "$repo_url" "$dir_name"

  echo "📁 Navigating to project directory..."
  cd "$dir_name" || return 1

  # Now check for specific Node.js version requirements
  echo "🔍 Detecting required Node.js version for this project..."
  ensure-node "" "./package.json"

  echo "⚙️ Setting up workshop..."
  # Set up pnpm workspace compatibility before running setup
  setup-pnpm-workspace

  # Use direct path to run npm
  echo "Running npm setup script..."
  real-npm run setup

  echo "✅ Setup complete! Run 'workshop start' to begin the workshop."
}

# ------- EpicWeb Workshop Auto-Detection -------
# Function to automatically detect and configure EpicWeb workshops
epic-detect() {
  # Only run in interactive shells
  [[ -o interactive ]] || return

  # Check for package.json with epicshop field
  if [[ -f "./package.json" ]] && grep -q '"epicshop"' "./package.json" 2>/dev/null; then
    if [[ "$EPIC_WORKSHOP_DETECTED" != "true" ]]; then
      echo "🚀 EpicWeb workshop detected! Setting up npm compatibility..."
      export EPIC_WORKSHOP_DETECTED="true"

      # Create workshop.env file if it doesn't exist
      if [[ ! -f "./.workshop.env" ]]; then
        # Detect Node.js version first
        local detected_version=$(detect-node-version "./package.json")

        cat > ./.workshop.env << EOF
# Workshop environment configuration
# This file is used by epic-web workshops to maintain settings through git updates
# Add this file to .gitignore to prevent it from being committed

# Node version to use for this workshop
NODE_VERSION=$detected_version

# Compatibility mode (npm or pnpm)
PACKAGE_MANAGER=npm
EOF
        echo ".workshop.env" >> ./.gitignore 2>/dev/null
        echo "Created .workshop.env configuration file (added to .gitignore)"
      fi

      # Set up proper Node.js version
      local node_version=$(grep NODE_VERSION ./.workshop.env 2>/dev/null | cut -d= -f2)
      if [[ -n "$node_version" ]]; then
        echo "🔍 Setting up Node.js $node_version for this workshop..."
        ensure-node "$node_version"
      fi

      # Alert user about enhanced compatibility mode
      echo "Workshop compatibility mode active. Use 'workshop' commands for best compatibility."
      echo "Run 'workshop help' to see available commands."
    fi
  else
    # Reset detection if we leave a workshop directory
    export EPIC_WORKSHOP_DETECTED="false"
  fi
}

# Add the detector to directory change hook
autoload -U add-zsh-hook
add-zsh-hook chpwd epic-detect

# Run detection on shell startup
epic-detect

# Enhanced epic-update function - update workshop while preserving local settings
epic-update() {
  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi

  # Check if this is an EpicWeb workshop
  if [[ ! -f "./package.json" ]] || ! grep -q '"epicshop"' "./package.json" 2>/dev/null; then
    echo "Error: Not in an EpicWeb workshop directory"
    return 1
  fi

  echo "Updating EpicWeb workshop..."

  # Save any local changes
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Stashing local changes..."
    git stash push -m "auto-stash before workshop update"
    local stashed=true
  fi

  # Update from remote
  echo "Pulling latest changes..."
  git pull

  # Re-run setup if needed
  if [[ -f "./package.json" ]] && grep -q '"setup"' "./package.json" 2>/dev/null; then
    echo "Running setup script with npm compatibility..."
    workshop setup
  fi

  # Restore stashed changes if needed
  if [[ "$stashed" = true ]]; then
    echo "Restoring local changes..."
    git stash pop
  fi

  echo "Workshop updated successfully!"
}

# ------- History Configuration -------
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=20000

# PNPM PATH configuration (single source of truth)
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
