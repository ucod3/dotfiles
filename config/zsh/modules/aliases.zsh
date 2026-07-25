# Command Aliases
# `code` is only remapped when the Insiders channel is actually installed —
# hardcoding it broke stable-VS Code users on a fresh fork (audit finding M2).
(( $+commands[code-insiders] )) && alias code="code-insiders"
# pnpm shims, only when pnpm is actually installed — it ships with
# `dotfiles.home.nodeTooling.enable`, which is off by default on a cold fork,
# and an unconditional alias makes `npm` a broken command there.
# `npx` is deliberately absent: the standalone `pnpx` binary was removed from
# pnpm years ago (superseded by `pnpm dlx`), so aliasing to it dangles.
if (( $+commands[pnpm] )); then
  alias npm="pnpm"
  alias yarn="pnpm"
  alias pn=pnpm
fi

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
alias change='${VISUAL:-${EDITOR:-nvim}} ${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/custom.zsh'
alias use-node="pnpm-use-node"
alias npm-real="real-npm"

# Node.js / pnpm helpers. `pnpm env` was removed from pnpm — the current API is
# `pnpm runtime`; tests/test_lib_node.bats asserts against the old spelling.
alias node-setup="echo 'Run: pnpm runtime set lts'"
alias node-versions="pnpm runtime list"

# File listing (safe replacements from common-aliases, without the buggy global aliases)
alias l='ls -lFh'
alias la='ls -lAFh'
alias ll='ls -l'
alias lt='ls -ltFh'
alias ldot='ls -ld .*'
alias lsr='ls -lARFh'

# Utility
alias grep='grep --color'
alias t='tail -f'
alias ff='find . -type f -name'
alias h='history'
alias help='man'