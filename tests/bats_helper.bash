# bats_helper.bash - Shared helpers for dotfiles bats tests
#
# Usage in test files:
#   load 'bats_helper'

# Report the separately captured stderr, when `run --separate-stderr` produced
# any. Without this a failing Nix or jq call reports only its stdout, which is
# usually the least informative half of the failure.
report_stderr() {
  if [ -n "${stderr:-}" ]; then
    echo "Stderr: $stderr"
  fi
}

# Assert that a command succeeds (status 0)
assert_success() {
  if [ "$status" -ne 0 ]; then
    echo "Expected success (status 0), got status $status"
    echo "Output: $output"
    report_stderr
    return 1
  fi
}

# Assert that a command fails (status non-zero)
assert_failure() {
  if [ "$status" -eq 0 ]; then
    echo "Expected failure (non-zero status), got status 0"
    echo "Output: $output"
    report_stderr
    return 1
  fi
}

# Assert output equals expected string
assert_output() {
  local expected="$1"
  if [ "$output" != "$expected" ]; then
    echo "Expected output: '$expected'"
    echo "Actual output:   '$output'"
    return 1
  fi
}

# Assert output contains substring
assert_output_contains() {
  local substring="$1"
  if [[ ! "$output" == *"$substring"* ]]; then
    echo "Expected output to contain: '$substring'"
    echo "Actual output: '$output'"
    return 1
  fi
}

# Create a temp file and return its path
make_temp() {
  mktemp -t "dotfiles_test.XXXXXX"
}

# Cleanup temp files (call in teardown)
cleanup_temp() {
  if [[ -n "${temp_files:-}" ]]; then
    for f in $temp_files; do
      rm -f "$f"
    done
  fi
}
