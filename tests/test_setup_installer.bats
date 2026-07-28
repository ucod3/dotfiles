#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  SETUP="$REPO_ROOT/setup.sh"
  TMP="$(mktemp -d -t setup_installer.XXXXXX)"
  HOME_DIR="$TMP/home"
  FAKE_BIN="$TMP/bin"
  FRAMEWORK_DIR="$HOME_DIR/dotfiles"
  PROFILE_DIR="$HOME_DIR/dotfiles-private"
  GIT_RECORD="$TMP/git-record"
  BOOTSTRAP_RECORD="$TMP/bootstrap-record"
  SETUP_HOST_RECORD="$TMP/setup-host-record"
  mkdir -p "$HOME_DIR" "$FAKE_BIN"

  cat > "$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Darwin\n' ;;
  -m) printf 'arm64\n' ;;
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
exit 0
EOF

  cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  config)
    case "${3:-}" in
      user.name) printf 'Test User\n' ;;
      user.email) printf 'test@example.com\n' ;;
      *) exit 0 ;;
    esac
    ;;
  clone)
    repo="${2:-}"
    dest="${3:-}"
    {
      printf 'REPO=%s\n' "$repo"
      printf 'DEST=%s\n' "$dest"
    } >> "$GIT_RECORD"
    mkdir -p "$dest"

    if [[ "$dest" == "$TEST_PROFILE_DIR" ]]; then
      printf '{ }\n' > "$dest/flake.nix"
      if [[ "${FAKE_PROFILE_MISSING_LOCK:-0}" != 1 ]]; then
        printf '{ }\n' > "$dest/flake.lock"
      fi
      cat > "$dest/bootstrap" <<'BOOTSTRAP'
#!/usr/bin/env bash
{
  printf 'PWD=%s\n' "$PWD"
  printf 'ARGS='
  printf '<%s>' "$@"
  printf '\n'
} > "$BOOTSTRAP_RECORD"
BOOTSTRAP
    elif [[ "$dest" == "$TEST_FRAMEWORK_DIR" ]]; then
      mkdir -p "$dest/scripts/bin"
      cat > "$dest/scripts/bin/setup-private-host" <<'SETUP_HOST'
#!/usr/bin/env bash
{
  printf 'DOTFILES_ROOT=%s\n' "${DOTFILES_ROOT:-}"
  printf 'DOTFILES_PRIVATE_FLAKE=%s\n' "${DOTFILES_PRIVATE_FLAKE:-}"
  printf 'ARGS='
  printf '<%s>' "$@"
  printf '\n'
} > "$SETUP_HOST_RECORD"
mkdir -p "$DOTFILES_PRIVATE_FLAKE"
printf '{ }\n' > "$DOTFILES_PRIVATE_FLAKE/flake.nix"
printf '{ }\n' > "$DOTFILES_PRIVATE_FLAKE/flake.lock"
cat > "$DOTFILES_PRIVATE_FLAKE/bootstrap" <<'BOOTSTRAP'
#!/usr/bin/env bash
{
  printf 'PWD=%s\n' "$PWD"
  printf 'ARGS='
  printf '<%s>' "$@"
  printf '\n'
} > "$BOOTSTRAP_RECORD"
BOOTSTRAP
SETUP_HOST
    fi
    ;;
  *)
    exit 0
    ;;
esac
EOF

  chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/xcode-select" "$FAKE_BIN/nix" "$FAKE_BIN/git"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_setup() {
  run env HOME="$HOME_DIR" \
          PATH="$FAKE_BIN:$PATH" \
          DOTFILES_FRAMEWORK_DIR="$FRAMEWORK_DIR" \
          DOTFILES_PROFILE_DIR="$PROFILE_DIR" \
          DOTFILES_INSTALL_HOST=test-mac \
          DOTFILES_INSTALL_USER=alice \
          TEST_FRAMEWORK_DIR="$FRAMEWORK_DIR" \
          TEST_PROFILE_DIR="$PROFILE_DIR" \
          GIT_RECORD="$GIT_RECORD" \
          BOOTSTRAP_RECORD="$BOOTSTRAP_RECORD" \
          SETUP_HOST_RECORD="$SETUP_HOST_RECORD" \
          "$@" \
          bash "$SETUP" "${SETUP_ARGS[@]}"
}

@test "help documents explicit new and restore journeys" {
  run bash "$SETUP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--new"* ]]
  [[ "$output" == *"--restore REPOSITORY"* ]]
  [[ "$output" == *"never regenerates"* ]]
  [[ "$output" == *"--activate"* ]]
}

@test "restore clones only the private profile and runs preflight" {
  SETUP_ARGS=(--restore owner/private-profile)
  run_setup
  [ "$status" -eq 0 ]

  grep -qF 'REPO=https://github.com/owner/private-profile.git' "$GIT_RECORD"
  grep -qF "DEST=$PROFILE_DIR" "$GIT_RECORD"
  [ "$(grep -c '^REPO=' "$GIT_RECORD")" -eq 1 ]
  grep -qF "PWD=$PROFILE_DIR" "$BOOTSTRAP_RECORD"
  grep -qF 'ARGS=<--host><test-mac>' "$BOOTSTRAP_RECORD"
  [ ! -e "$SETUP_HOST_RECORD" ]
  [[ "$output" == *"Invoking the profile-owned restore contract"* ]]
}

@test "restore forwards explicit activation flags to the profile" {
  SETUP_ARGS=(--restore git@github.com:owner/private-profile.git --activate --yes)
  run_setup
  [ "$status" -eq 0 ]

  grep -qF 'ARGS=<--host><test-mac><--activate><--yes>' "$BOOTSTRAP_RECORD"
}

@test "restore refuses an existing profile destination without moving it" {
  mkdir -p "$PROFILE_DIR"
  printf 'keep\n' > "$PROFILE_DIR/existing"

  SETUP_ARGS=(--restore owner/private-profile)
  run_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"destination already exists"* ]]
  [ "$(cat "$PROFILE_DIR/existing")" = keep ]
  [ ! -e "$GIT_RECORD" ]
}

@test "restore requires the committed profile lock before bootstrap" {
  SETUP_ARGS=(--restore owner/private-profile)
  run_setup FAKE_PROFILE_MISSING_LOCK=1
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing committed flake.lock"* ]]
  [ ! -e "$BOOTSTRAP_RECORD" ]
  [ ! -e "$SETUP_HOST_RECORD" ]
}

@test "new journey creates a readable profile then runs preflight" {
  SETUP_ARGS=(--new --framework owner/framework)
  run_setup
  [ "$status" -eq 0 ]

  grep -qF 'REPO=https://github.com/owner/framework.git' "$GIT_RECORD"
  grep -qF "DEST=$FRAMEWORK_DIR" "$GIT_RECORD"
  grep -qF "DOTFILES_ROOT=$FRAMEWORK_DIR" "$SETUP_HOST_RECORD"
  grep -qF "DOTFILES_PRIVATE_FLAKE=$PROFILE_DIR" "$SETUP_HOST_RECORD"
  grep -qF 'ARGS=<--host><test-mac><--user><alice><--fork><https://github.com/owner/framework.git>' "$SETUP_HOST_RECORD"
  grep -qF 'ARGS=<--host><test-mac>' "$BOOTSTRAP_RECORD"
}

@test "new journey also keeps activation explicit" {
  SETUP_ARGS=(--new --activate)
  run_setup
  [ "$status" -eq 0 ]

  grep -qF 'ARGS=<--host><test-mac><--activate>' "$BOOTSTRAP_RECORD"
  run grep -qF '<--yes>' "$BOOTSTRAP_RECORD"
  [ "$status" -ne 0 ]
}

@test "yes is invalid without activation" {
  SETUP_ARGS=(--restore owner/private-profile --yes)
  run_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"--yes is only valid with --activate"* ]]
  [ ! -e "$GIT_RECORD" ]
}

@test "conflicting journeys are rejected before prerequisites" {
  SETUP_ARGS=(--new --restore owner/private-profile)
  run_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"choose exactly one journey"* ]]
  [ ! -e "$GIT_RECORD" ]
}
