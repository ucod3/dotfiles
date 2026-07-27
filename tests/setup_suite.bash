# tests/setup_suite.bash — suite-wide environment for every bats file
#
# bats loads this once, before any test file, so what it exports applies to the
# whole suite.
#
# WHY THIS EXISTS
#   `dot validate` runs `bats tests/` from an interactive terminal, and bats
#   captures each test's stdout/stderr. A script under test that prompts is
#   therefore invisible AND blocking: the read waits on a keyboard nobody knows
#   to type at. Redirecting stdin from /dev/null is not enough — the process
#   still inherits a controlling terminal, so a `< /dev/tty` fallback (the one
#   in scripts/bin/setup-private-host) opens successfully and blocks anyway.
#
#   That combination hung `dot validate`, `dot promote`, `dot update` and every
#   `git commit` (the pre-commit hook runs `validate --quick`, and bats sits
#   outside the QUICK_MODE guard). CI never saw it: with no controlling
#   terminal the /dev/tty probe fails, so the suite passed green.
#
#   Declaring the whole suite non-interactive fixes it structurally — any
#   prompt added to any script in future is covered, not just today's.

setup_suite() {
  export DOTFILES_NONINTERACTIVE=1
}
