# utils.zsh — General-purpose shell utilities
# Part of: config/zsh/modules/

# Create npm/npx/yarn shim wrappers in ~/.local/bin (runs once per machine)
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

# mkcd — create a directory and cd into it immediately
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# aliases — look up your custom aliases
# Usage:
#   aliases         → show all custom aliases grouped by module file
#   aliases git     → filter by keyword
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
