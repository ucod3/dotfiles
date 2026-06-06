# Command Aliases
alias code="code-insiders"
alias npm="pnpm"
alias npx="pnpx"
alias yarn="pnpm"
alias pn=pnpm

# Unified dotfiles dispatcher (dot <subcommand>)
# See: dot help   for the full reference
alias dot='${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/dot'

# Convenience shorthands (all delegate to dot internally)
alias update='${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/update'
alias apps='${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/apps'
alias change='code-insiders ${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/custom.zsh'
alias use-node="pnpm-use-node"
alias use-nvm="nvm-init && nvm use"
alias npm-real="real-npm"

# Node.js / pnpm aliases
alias node-setup="echo 'Run: pnpm env use --global node@lts'"
alias node-versions="pnpm env list"

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