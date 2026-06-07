#!/usr/bin/env bats
#
# Unit tests for lib/node.sh helper functions
#

setup() {
  # Source the file under test
  source "$BATS_TEST_DIRNAME/../lib/node.sh"
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

@test "_find_node returns error when node not found" {
  # Temporarily remove node from PATH
  local saved_path="$PATH"
  PATH="/nonexistent"

  run _find_node
  PATH="$saved_path"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Node.js not found"* ]]
}

@test "error message references correct pnpm command" {
  # Bug fix verification: lib/node.sh line 38 should reference pnpm 11+ API
  # not the deprecated 'pnpm env use' command

  local saved_path="$PATH"
  PATH="/nonexistent"

  run _find_node 2>&1
  PATH="$saved_path"

  # Should reference pnpm runtime set, not pnpm env use
  [[ "$output" == *"pnpm runtime set"* ]]
  [[ "$output" != *"pnpm env use"* ]]
}
