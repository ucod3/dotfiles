# Custom interactive Zsh logic sourced by Home Manager.
# Home Manager loads completion, autosuggestions, syntax highlighting, fzf,
# zoxide and (optionally) Oh My Zsh. Keep only custom shell logic here.

# Source modular configuration files
# Use DOTFILES_ROOT if set, otherwise default to ~/dotfiles
MODULES_DIR="${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules"

# WHICH modules load is a Nix decision, not a shell one.
#
# This file is read verbatim into ~/.zshrc, so it cannot see `dotfiles.home.*`
# options directly. nix/home/home.nix prepends `export DOTFILES_ZSH_MODULES=...`
# ahead of this content, listing exactly the modules the enabled toggles ask
# for. The default below is what a cold fork gets with no Nix in the picture at
# all: the neutral core, and nothing that redefines a standard command or
# touches the project you happen to be standing in (ADR-011).
#
# Deliberately absent from the default: aliases-personal (rewrites `npm`, `ls`,
# `help`), node/npm-compat (wrap `pnpm`), and workshop (`epic-detect` writes
# .workshop.env into any repo you cd into).
DOTFILES_ZSH_MODULES="${DOTFILES_ZSH_MODULES:-init utils aliases exports}"

if [[ -d "$MODULES_DIR" ]]; then
  for _dotfiles_module in ${=DOTFILES_ZSH_MODULES}; do
    if [[ -r "$MODULES_DIR/$_dotfiles_module.zsh" ]]; then
      source "$MODULES_DIR/$_dotfiles_module.zsh"
    else
      echo "Warning: Zsh module not found: $MODULES_DIR/$_dotfiles_module.zsh"
    fi
  done
  unset _dotfiles_module
else
  echo "Warning: Zsh modules directory not found at $MODULES_DIR"
fi

# ── Your stuff, unmanaged ─────────────────────────────────────────────────────
# Two escape hatches, both gitignored and both loaded last so they win over
# anything above. Neither is touched by `dot rebuild`, so you can add aliases,
# source nvm/rustup, or set up Warp without editing a tracked framework file and
# without your changes being clobbered on the next build.
#
#   config/zsh/custom.local.zsh   travels with the checkout
#   ~/.zshrc.local                belongs to the machine
#
# See config/zsh/custom.local.zsh.example for a starting point.
[[ -r "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/custom.local.zsh" ]] \
  && source "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/custom.local.zsh"
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Never let a failing final test set a non-zero $? for the first prompt.
true
