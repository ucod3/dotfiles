#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  GENERATOR="$REPO_ROOT/scripts/lib/generate-private-profile.sh"
  TMP="$(mktemp -d -t private_bootstrap.XXXXXX)"
  PRIVATE="$TMP/dotfiles-private"
  FAKE_BIN="$TMP/bin"
  RECORD="$TMP/nix-record"
  mkdir -p "$FAKE_BIN"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

generate_profile() {
  run bash "$GENERATOR" \
    --root "$PRIVATE" \
    --host test-mac \
    --user alice \
    "$@"
  [ "$status" -eq 0 ]
}

write_fake_prerequisites() {
  cat > "$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Darwin\n' ;;
  -m) printf '%s\n' "${FAKE_ARCH:-arm64}" ;;
  *) exit 2 ;;
esac
EOF

  cat > "$FAKE_BIN/xcode-select" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -p) printf '/Library/Developer/CommandLineTools\n' ;;
  --install) exit 0 ;;
  *) exit 2 ;;
esac
EOF

  cat > "$FAKE_BIN/nix" <<'EOF'
#!/usr/bin/env bash
{
  printf 'PWD=%s\n' "$PWD"
  printf 'NIX_CONFIG=%s\n' "${NIX_CONFIG:-}"
  printf 'ARGS='
  printf '<%s>' "$@"
  printf '\n'
} > "$BOOTSTRAP_RECORD"
EOF

  chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/xcode-select" "$FAKE_BIN/nix"
}

@test "profile bootstrap delegates to the pinned restore app" {
  generate_profile
  write_fake_prerequisites

  run env PATH="$FAKE_BIN:$PATH" \
          BOOTSTRAP_RECORD="$RECORD" \
          "$PRIVATE/bootstrap" --host test-mac --json
  [ "$status" -eq 0 ]

  [[ "$output" == *"nix run .#restore -- --profile $PRIVATE --host test-mac --json"* ]]
  grep -qF "PWD=$PRIVATE" "$RECORD"
  grep -qF 'NIX_CONFIG=experimental-features = nix-command flakes' "$RECORD"
  grep -qF "ARGS=<run><.#restore><--><--profile><$PRIVATE><--host><test-mac><--json>" "$RECORD"

  run grep -F 'github:ucod3/dotfiles' "$PRIVATE/bootstrap"
  [ "$status" -ne 0 ]
  run grep -F 'darwin-rebuild' "$PRIVATE/bootstrap"
  [ "$status" -ne 0 ]
}

@test "profile bootstrap forwards explicit activation options unchanged" {
  generate_profile
  write_fake_prerequisites

  run env PATH="$FAKE_BIN:$PATH" \
          BOOTSTRAP_RECORD="$RECORD" \
          "$PRIVATE/bootstrap" --host test-mac --activate --yes
  [ "$status" -eq 0 ]

  [[ "$output" == *"--host test-mac --activate --yes"* ]]
  grep -qF "ARGS=<run><.#restore><--><--profile><$PRIVATE><--host><test-mac><--activate><--yes>" "$RECORD"
}

@test "profile bootstrap refuses an architecture mismatch before Nix" {
  generate_profile --system x86_64-darwin
  write_fake_prerequisites

  run env PATH="$FAKE_BIN:$PATH" \
          BOOTSTRAP_RECORD="$RECORD" \
          "$PRIVATE/bootstrap"
  [ "$status" -ne 0 ]
  [[ "$output" == *"profile targets x86_64-darwin but this Mac is aarch64-darwin"* ]]
  [ ! -e "$RECORD" ]
}

@test "profile bootstrap help is available without prerequisites" {
  generate_profile

  run "$PRIVATE/bootstrap" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./bootstrap [RESTORE OPTIONS]"* ]]
  [[ "$output" == *"Without --activate"* ]]
  [[ "$output" == *"--activate --yes"* ]]
  [[ "$output" == *"Neither path updates flake.lock"* ]]
}
