#!/usr/bin/env bats
#
# Regression tests for `scripts/bin/rebuild`.
#
# The script itself cannot be executed here — it sudo-switches the live system —
# so behaviours are pinned by asserting on its source, the idiom already used in
# test_cold_clone.bats. Argument parsing is cheap to exercise for real, because
# a bad flag exits before any privileged work happens.
#
# These pin ADR-009: the live system builds from the revision the private flake
# lock names, and only an explicit flag can substitute a local working tree.
#

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  REBUILD="$REPO_ROOT/scripts/bin/rebuild"
}

# Comments and advisory messages legitimately name the commands this script must
# not run — the bump recipe is printed for the user to run by hand. Assertions
# about what rebuild *does* must therefore ignore comment lines and log_* output.

@test "rebuild never updates the private flake lock" {
  # The original leak: rebuild ran `nix flake update dotfiles` whenever the lock
  # differed from the local checkout, so any experimental branch became the live
  # system on the next rebuild. A rebuild must never mutate the pin.
  run bash -c "grep -vE '^[[:space:]]*#' '$REBUILD' | grep -vE '^[[:space:]]*log_' | grep -n 'nix flake update'"
  [ "$status" -ne 0 ]
}

@test "the staleness check compares against origin/main, not HEAD" {
  # Comparing against `rev-parse HEAD` meant whichever branch happened to be
  # checked out was treated as the intended system. The pin tracks the published
  # branch, so that is what it must be measured against.
  run grep -q "rev-parse origin/main" "$REBUILD"
  [ "$status" -eq 0 ]

  run bash -c "grep -vE '^[[:space:]]*#' '$REBUILD' | grep -qE 'rev-parse HEAD'"
  [ "$status" -ne 0 ]
}

@test "a stale pin is advisory and does not fail the rebuild" {
  # Reporting staleness must not change the exit status: a deliberately pinned
  # older revision is a valid state, not an error.
  run grep -q "Not updating automatically" "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "--override-local overrides the dotfiles input" {
  run grep -q -- "--override-input dotfiles" "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "--override-local uses git+file:, never a bare path" {
  # ADR-004: a bare path selects the `path:` scheme, which copies .git/ into the
  # store and hard-fails on the core.fsmonitor socket this repo enables. It also
  # loses the R2 semantics (staged visible, untracked invisible).
  run grep -q 'git+file://\$OVERRIDE_ABS' "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "--override-local does not write the flake lock" {
  # Without this, a one-off local test would silently become the new pin and the
  # next plain rebuild would still be running the override.
  run grep -q -- "--no-write-lock-file" "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "the switch command keeps --impure and a dynamic hostname" {
  # R4 / ADR-004: --impure is what makes the gitignored .local/ layer readable,
  # and the host must never be hardcoded.
  run grep -q 'switch --flake "${FLAKE_ROOT}#${HOSTNAME}" --impure' "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "the sudo boundary still carries DOTFILES_LOCAL and HOME" {
  # ADR-004: sudo may rewrite $HOME, so both are passed explicitly.
  run grep -q 'sudo env DOTFILES_LOCAL="$DOTFILES_LOCAL" HOME="$HOME"' "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "extra nix flags expand safely when empty under set -u" {
  # `rebuild` runs with `set -euo pipefail`; a bare "${NIX_FLAGS[@]}" expansion
  # aborts on an empty array in the default, no-flag case.
  run grep -q 'NIX_FLAGS\[@\]+' "$REBUILD"
  [ "$status" -eq 0 ]
}

@test "rebuild accepts --help and exits cleanly" {
  run "$REBUILD" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--override-local"* ]]
}

@test "rebuild rejects an unknown flag" {
  # Before this parser existed, rebuild took no arguments at all, so `dot rebuild
  # --override-local` was accepted and silently did nothing — the worst outcome
  # for a flag whose whole purpose is to change which source tree goes live.
  run "$REBUILD" --definitely-not-a-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "--override-local rejects a path that is not a git repository" {
  # git+file: on a non-repo fails deep inside Nix with an opaque error.
  #
  # This must be reachable on ANY machine, which is why the check now runs
  # beside argument parsing rather than just before the build: behind
  # `require_nix` and the host lookup, a machine with no matching
  # darwinConfiguration reported "No configuration found for hostname" instead
  # — an error about something the user had not done wrong.
  run "$REBUILD" --override-local=/tmp
  [ "$status" -eq 1 ]
  [[ "$output" == *"not one"* ]]
}

@test "setup-private-host generates a published flake ref when origin is GitHub" {
  # A regenerated private flake must not reintroduce the local-path coupling.
  run grep -q 'dotfiles_flake_ref' "$REPO_ROOT/scripts/bin/setup-private-host"
  [ "$status" -eq 0 ]

  run grep -q "printf 'github:%s" "$REPO_ROOT/scripts/bin/setup-private-host"
  [ "$status" -eq 0 ]
}
