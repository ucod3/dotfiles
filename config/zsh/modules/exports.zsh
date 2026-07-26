# Environment Variable Exports
#
# Neutral core only. Two previous inhabitants of this file have moved:
#
#   PNPM_HOME (and its PATH entry) → config/zsh/.zshenv, because env vars
#     belong there per the zsh startup contract and three copies had drifted.
#
#   npm_config_prefix → modules/node.zsh, because redirecting where `npm -g`
#     installs is part of the pnpm-first workflow, not something a neutral
#     shell should do to a user who never opted into it (ADR-011).
#
# Add machine-local exports to config/zsh/custom.local.zsh or ~/.zshrc.local
# instead of here — both are gitignored and sourced last.
