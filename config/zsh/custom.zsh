# Custom interactive Zsh logic sourced by Home Manager.
# Home Manager now loads Oh My Zsh, completion, autosuggestions,
# syntax highlighting, fzf, and zoxide. Keep only custom Shell logic here.

# Source modular configuration files
# Use DOTFILES_ROOT if set, otherwise default to ~/dotfiles
MODULES_DIR="${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules"

# Load modules in order of dependencies
if [[ -d "$MODULES_DIR" ]]; then
  source "$MODULES_DIR/init.zsh"
  source "$MODULES_DIR/node.zsh"
  source "$MODULES_DIR/functions.zsh"
  source "$MODULES_DIR/aliases.zsh"
  source "$MODULES_DIR/workshop.zsh"
  source "$MODULES_DIR/exports.zsh"
else
  echo "Warning: Zsh modules directory not found at $MODULES_DIR"
fi