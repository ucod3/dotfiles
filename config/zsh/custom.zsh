# Custom interactive Zsh logic sourced by Home Manager.
# Home Manager now loads Oh My Zsh, completion, autosuggestions,
# syntax highlighting, fzf, and zoxide. Keep only custom Shell logic here.

# Source modular configuration files
MODULES_DIR="${0:A:h}/modules"

# Load modules in order of dependencies
source "$MODULES_DIR/init.zsh"
source "$MODULES_DIR/node.zsh"
source "$MODULES_DIR/functions.zsh"
source "$MODULES_DIR/aliases.zsh"
source "$MODULES_DIR/workshop.zsh"
source "$MODULES_DIR/exports.zsh"