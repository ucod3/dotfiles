# utils.zsh — General-purpose shell utilities
# Part of: config/zsh/modules/
#
# REMOVED (ADR-011): this file used to write executable `npm`, `npx` and `yarn`
# shims into ~/.local/bin on first shell start, each one `exec pnpm "$@"`. That
# was wrong three times over. It was imperative — a file written by a shell
# rc, outside Nix's knowledge, that no rebuild or rollback could ever retract.
# It was global — ~/.local/bin is early on PATH, so it broke `npm` for every
# process on the machine, not just interactive shells. And it was unconditional
# — it ran on a cold fork where pnpm is not even installed, leaving a shim that
# execs a command that does not exist.
#
# If a machine still has them from a previous install, remove them by hand:
#     rm -f ~/.local/bin/npm ~/.local/bin/npx ~/.local/bin/yarn
# Declarative config cannot clean up an imperative write it no longer makes.
#
# The supported way to prefer pnpm is `dotfiles.home.zsh.personalAliases.enable`,
# which aliases npm→pnpm for interactive shells only, and only when pnpm exists.

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
  local dotfiles="${DOTFILES_ROOT:-$HOME/dotfiles}"
  local modules_dir="$dotfiles/config/zsh/modules"

  # Your own unmanaged files are searched too — otherwise `aliases` reports on
  # the framework's aliases while staying blind to the ones you actually wrote.
  local -a sources
  sources=("$modules_dir"/*.zsh(N) "$dotfiles/config/zsh/custom.local.zsh"(N) "$HOME/.zshrc.local"(N))

  echo ""
  echo "── Your Aliases ─────────────────────────────"

  if [[ -n "$search" ]]; then
    echo "  (filtered: '$search')"
    echo ""
    grep -h "^alias" "${sources[@]}" 2>/dev/null \
      | grep -i "$search" \
      | sed "s/^alias /  /" | sort
    echo ""
    echo "── All Active Aliases (filtered) ────────────"
    alias | grep -i "$search" | grep -v "^aliases\b" | sed "s/^/  /" | head -20
  else
    echo ""
    for f in "${sources[@]}"; do
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
    echo "  change         → edit your own custom.local.zsh"
  fi
  echo "─────────────────────────────────────────────"
  echo ""
}

# dotenv-init — scaffold a new .envrc for local project overrides
# Usage: dotenv-init [template]
# Templates: node (default), api, db
#
# This implements the Bucket 2 Cross-Boundary rule from global_rules.md:
# "Keep project-specific env vars out of core dotfiles; use direnv + .envrc"
dotenv-init() {
  local template="${1:-node}"

  if [[ -f "./.envrc" ]]; then
    echo "⚠️  .envrc already exists. Edit manually or run: rm .envrc && dotenv-init $template"
    return 1
  fi

  case "$template" in
    node)
      cat > ./.envrc << 'EOF'
# Node.js project environment
export NODE_ENV=development
export PORT=3000
EOF
      ;;
    api)
      cat > ./.envrc << 'EOF'
# API client environment
export API_BASE_URL=http://localhost:3000
export API_KEY=changeme_in_envrc
EOF
      ;;
    db)
      cat > ./.envrc << 'EOF'
# Database environment
export DATABASE_URL=postgres://localhost:5432/mydb
export POSTGRES_USER=$USER
EOF
      ;;
    *)
      echo "Unknown template: $template"
      echo "Available: node, api, db"
      return 1
      ;;
  esac

  echo "✅ Created .envrc with $template template"
  echo "Review the file, then run: direnv allow"
}
