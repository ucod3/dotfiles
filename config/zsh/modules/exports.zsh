# Environment Variable Exports
export npm_config_prefix="$HOME/.local"

# Add PNPM_HOME to PATH if not already present
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac