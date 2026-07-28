#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  VALIDATE="$REPO_ROOT/scripts/bin/validate"
  TMP="$(mktemp -d -t dotfiles_validate_test.XXXXXX)"
  STUB_BIN="$TMP/bin"
  NIX_CALLED="$TMP/nix-called"
  BATS_ENV="$TMP/bats-env"
  mkdir -p "$STUB_BIN"

  cat > "$STUB_BIN/nix" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >> "$NIX_CALLED"
EOF
  cp "$STUB_BIN/nix" "$STUB_BIN/nix-instantiate"

  cat > "$STUB_BIN/bats" <<'EOF'
#!/usr/bin/env bash
{
  printf 'quick=%s\n' "${DOTFILES_VALIDATE_QUICK:-unset}"
  printf 'args=%s\n' "$*"
} > "$BATS_ENV"
EOF

  cat > "$STUB_BIN/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  chmod +x \
    "$STUB_BIN/nix" \
    "$STUB_BIN/nix-instantiate" \
    "$STUB_BIN/bats" \
    "$STUB_BIN/zsh"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_validate() {
  run env \
    PATH="$STUB_BIN:$PATH" \
    NIX_CALLED="$NIX_CALLED" \
    BATS_ENV="$BATS_ENV" \
    bash "$VALIDATE" "$@"
}

@test "quick validation runs unit tests without invoking Nix evaluation" {
  run_validate --quick

  assert_success
  [ ! -e "$NIX_CALLED" ]
  grep -qx 'quick=1' "$BATS_ENV"
  grep -qx 'args=tests/' "$BATS_ENV"
}

@test "full validation retains Nix evaluation and marks the full test contract" {
  run_validate

  assert_success
  [ -s "$NIX_CALLED" ]
  grep -qx 'quick=0' "$BATS_ENV"
  grep -qx 'args=tests/' "$BATS_ENV"
}
