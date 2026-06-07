# Environment Variable Exports
export npm_config_prefix="$HOME/.local"

# PNPM configuration (respect user override via .envrc or other means)
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
