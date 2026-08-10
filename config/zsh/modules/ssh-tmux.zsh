# Attach interactive SSH logins to one persistent tmux session.
#
# Gated behind `dotfiles.home.zsh.sshTmux.enable` (ADR-011). This module does
# not add to your shell, it replaces it, so it is never on by default — not
# even under the example profile.
#
# Why this file and not .zshenv: zsh reads .zshenv on EVERY invocation and
# .zshrc only on interactive ones. `ssh host command`, scp and rsync all run a
# non-interactive shell, so they never reach this module. An `exec` in .zshenv
# would hijack every remote command on the machine, including the ones you
# would need to undo it.

# Belt and braces. custom.zsh is only ever read from .zshrc, so `interactive`
# is already implied — but the tests source this file directly, and an exec
# that escapes its guard is not a risk worth taking for one cheap test.
if [[ -o interactive ]] \
  && [[ -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]] \
  && [[ -z "${TMUX:-}" ]] \
  && command -v tmux >/dev/null 2>&1; then
  # -A attaches to `remote` when it already exists instead of failing, so one
  # session survives every disconnect and reconnect. exec replaces the login
  # shell, so detaching ends the SSH session cleanly rather than dropping you
  # at a second, unmanaged prompt.
  exec tmux new-session -A -s remote
fi
