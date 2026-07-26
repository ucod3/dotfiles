# Personal aliases — one example profile, OFF by default.
#
# Loaded only when `dotfiles.home.zsh.personalAliases.enable` is set. Everything
# here redefines a command the system already provides, which is exactly why it
# is not part of the framework core: a fork should not silently inherit someone
# else's idea of what `npm`, `ls` or `help` mean (ADR-011).
#
# Treat this file as a worked example. Copy what you like into your own
# config/zsh/custom.local.zsh (or ~/.zshrc.local), which is unmanaged and loads
# last, rather than editing this one — it is tracked, so your edits would show
# up as diffs against upstream forever.

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

# Node.js / pnpm helpers. These only work when the node workflow modules are
# loaded too (`dotfiles.home.zsh.nodeWorkflow.enable`).
alias use-node="pnpm-use-node"
alias npm-real="real-npm"
# `pnpm env` was removed from pnpm — the current API is `pnpm runtime`;
# tests/test_lib_node.bats asserts against the old spelling.
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
