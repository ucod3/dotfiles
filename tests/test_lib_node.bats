#!/usr/bin/env bats
#
# Unit tests for lib/node.sh helper functions
#

setup() {
  load 'bats_helper'
  # Source the file under test
  source "$BATS_TEST_DIRNAME/../lib/node.sh"

  # A directory guaranteed to contain no executables, for tests that need a
  # PATH with no node on it. bats creates BATS_TEST_TMPDIR per test and removes
  # it afterwards; the fallback keeps this working on older bats releases.
  EMPTY_BIN="${BATS_TEST_TMPDIR:-}/empty-bin"
  mkdir -p "$EMPTY_BIN" 2>/dev/null || EMPTY_BIN="/nonexistent"
}

# Simulate a machine with no Node.js installed anywhere.
#
# Emptying PATH is necessary but NOT sufficient. _find_node also probes
# /usr/local/bin/node, /opt/homebrew/bin/node and /usr/bin/node by *absolute*
# path, which no amount of PATH isolation can hide. GitHub Actions runner
# images ship node at /usr/local/bin/node, so the fallback loop resolved it and
# the "not found" tests below failed on CI while passing on a Mac with no
# system node. Stubbing _node_fallback_paths closes that second door.
no_node_anywhere() {
  PATH="$EMPTY_BIN"
  _node_fallback_paths() { :; }
}

@test "_find_node returns path when node is available" {
  # This test depends on node being in PATH - skip if not available
  if ! command -v node >/dev/null 2>&1; then
    skip "node not available in PATH"
  fi

  run _find_node
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ -x "$output" ]
}

@test "_find_node falls back to a standard location when PATH has no node" {
  # Guards the seam: _node_fallback_paths must still be consulted, otherwise
  # the stub used by the tests below would be hiding dead code.
  local saved_path="$PATH"
  local fake_node="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/fake-node"
  printf '#!/bin/sh\necho fake\n' > "$fake_node"
  chmod +x "$fake_node"   # external command — must run before PATH is emptied

  PATH="$EMPTY_BIN"
  _node_fallback_paths() { echo "$fake_node"; }

  run _find_node
  PATH="$saved_path"

  [ "$status" -eq 0 ]
  [ "$output" = "$fake_node" ]
}

@test "_find_node returns error when node not found" {
  local saved_path="$PATH"
  no_node_anywhere

  run _find_node
  PATH="$saved_path"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Node.js not found"* ]]
}

@test "error message references correct pnpm command" {
  # Bug fix verification: the not-found message should reference the pnpm 11+
  # API, not the deprecated 'pnpm env use' command
  local saved_path="$PATH"
  no_node_anywhere

  run _find_node
  PATH="$saved_path"

  # Should reference pnpm runtime set, not pnpm env use
  [[ "$output" == *"pnpm runtime set"* ]]
  [[ "$output" != *"pnpm env use"* ]]
}
