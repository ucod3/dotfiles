# Framework aliases — the `dot` dispatcher and its subcommands.
#
# This module is ALWAYS loaded. It contains only entry points into this repo's
# own tooling: nothing here redefines a standard command, so it is safe on any
# machine regardless of what the user has installed.
#
# Personal aliases (ls shorthands, npm→pnpm, grep --color, help=man) live in
# aliases-personal.zsh and load only when `dotfiles.home.zsh.personalAliases`
# is enabled — they are one person's muscle memory, not a framework contract
# (ADR-011).

# Unified dotfiles dispatcher (dot <subcommand>)
# See: dot help   for the full reference
alias dot='${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/dot'

# Convenience shorthands. These go through `dot` so there is one dispatch path;
# `rebuild` and `validate` in particular had no alias at all despite ~10 places
# in the repo telling the user to "then run: rebuild".
alias rebuild='dot rebuild'
alias validate='dot validate'
alias update='dot update'
alias apps='dot apps'
alias promote='dot promote'

# `change` opens the unmanaged escape hatch, not a tracked framework file:
# editing custom.zsh means your edits are overwritten on the next rebuild,
# whereas custom.local.zsh is yours and is sourced last.
alias change='${VISUAL:-${EDITOR:-vi}} ${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/custom.local.zsh'
