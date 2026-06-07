#!/usr/bin/env bats
#
# Unit tests for node.zsh version detection and management functions
# These tests validate the logic bugs fixed in the 2025-01-18 review round
#
# Run with: bats tests/

setup() {
  # Source the file under test
  load '../config/zsh/modules/node.zsh'
}

# ── detect-node-version tests ────────────────────────────────────────────────

@test "detect-node-version handles >=20.11.0 (extracts major version only)" {
  # Create a temporary package.json with >= constraint
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": ">=20.11.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]  # Should be single line with just "20"

  rm -f "$tmpfile"
}

@test "detect-node-version handles ^20.11.0 (extracts major version only)" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": "^20.11.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]

  rm -f "$tmpfile"
}

@test "detect-node-version handles ~20.11.0 (extracts major version only)" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": "~20.11.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]

  rm -f "$tmpfile"
}

@test "detect-node-version handles raw semver 20.11.0 (extracts major only)" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": "20.11.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "20" ]  # Bug fix: was returning full "20.11.0" string

  rm -f "$tmpfile"
}

@test "detect-node-version returns single line (not multi-line)" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": ">=20.11.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]

  # Count lines in output - should be exactly 1
  local line_count="$(echo "$output" | wc -l)"
  [ "$line_count" -eq 1 ]

  rm -f "$tmpfile"
}

@test "detect-node-version returns 'lts' for missing package.json" {
  run detect-node-version "/nonexistent/package.json"
  [ "$status" -eq 0 ]
  [ "$output" = "lts" ]
}

@test "detect-node-version returns 'lts' for package.json without node field" {
  local tmpfile="$(mktemp)"
  echo '{"name": "test"}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "lts" ]

  rm -f "$tmpfile"
}

# ── Version comparison edge cases ───────────────────────────────────────────

@test "detect-node-version handles 18.x.x versions" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": ">=18.20.5"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "18" ]

  rm -f "$tmpfile"
}

@test "detect-node-version handles single digit versions" {
  local tmpfile="$(mktemp)"
  echo '{"engines": {"node": ">=8.17.0"}}' > "$tmpfile"

  run detect-node-version "$tmpfile"
  [ "$status" -eq 0 ]
  [ "$output" = "8" ]

  rm -f "$tmpfile"
}
