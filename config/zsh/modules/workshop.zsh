# Workshop-specific logic for EpicWeb and other workshops

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