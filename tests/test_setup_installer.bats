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
  APPS_RECORD="$TMP/apps-record"
  APPS_CHANGED_FILE="$TMP/apps-changed"
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
if [[ "${1:-}" == "-C" ]]; then
  repo="${2:-}"
  command="${3:-}"
  shift 3
  case "$command" in
    status)
      [[ -e "$APPS_CHANGED_FILE" ]] && printf ' M apps/homebrew-casks.nix\n'
      ;;
    add)
      printf 'PROFILE_GIT=<add><%s>\n' "$*" >> "$GIT_RECORD"
      ;;
    commit)
      printf 'PROFILE_GIT=<commit><%s>\n' "$*" >> "$GIT_RECORD"
      rm -f "$APPS_CHANGED_FILE"
      ;;
    config)
      printf 'PROFILE_GIT=<config><%s>\n' "$*" >> "$GIT_RECORD"
      ;;
    restore)
      printf 'PROFILE_GIT=<restore><%s>\n' "$*" >> "$GIT_RECORD"
      rm -f "$APPS_CHANGED_FILE"
      ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "--no-pager" && "${2:-}" == "-C" ]]; then
  printf 'diff --git a/apps/example b/apps/example\n'
  exit 0
fi
case "${1:-}" in
  config)
    if [[ "${2:-}" == "--global" && "$#" -gt 3 ]]; then
      printf 'GLOBAL_GIT_WRITE=<%s>\n' "$*" >> "$GIT_RECORD"
      exit 0
    fi
    [[ "${FAKE_GIT_IDENTITY_MISSING:-0}" != 1 ]] || exit 0
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
  printf 'GIT_AUTHOR_NAME=%s\n' "${GIT_AUTHOR_NAME:-}"
  printf 'GIT_AUTHOR_EMAIL=%s\n' "${GIT_AUTHOR_EMAIL:-}"
  printf 'GIT_COMMITTER_NAME=%s\n' "${GIT_COMMITTER_NAME:-}"
  printf 'GIT_COMMITTER_EMAIL=%s\n' "${GIT_COMMITTER_EMAIL:-}"
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
      cat > "$dest/scripts/bin/apps" <<'APPS'
#!/usr/bin/env bash
{
  printf 'ARGS='
  printf '<%s>' "$@"
  printf '\n'
} >> "$APPS_RECORD"
if [[ -n "${FAKE_APPS_FAIL_ON:-}" && "$*" == *"$FAKE_APPS_FAIL_ON"* ]]; then
  exit 1
fi
mkdir -p "$DOTFILES_PRIVATE_FLAKE/apps"
: > "$APPS_CHANGED_FILE"
APPS
      chmod +x "$dest/scripts/bin/apps"
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
          APPS_RECORD="$APPS_RECORD" \
          APPS_CHANGED_FILE="$APPS_CHANGED_FILE" \
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
  [[ "$output" == *"--cask NAME"* ]]
  [[ "$output" == *"--nix-package ATTR"* ]]
  [[ "$output" == *"--mas-app NAME=REF"* ]]
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

@test "missing global identity is saved only in the new private profile" {
  SETUP_ARGS=(--new --skip-apps)
  run_setup \
    FAKE_GIT_IDENTITY_MISSING=1 \
    GIT_AUTHOR_NAME="Profile User" \
    GIT_AUTHOR_EMAIL="profile-email"
  [ "$status" -eq 0 ]

  grep -qF 'GIT_AUTHOR_NAME=Profile User' "$SETUP_HOST_RECORD"
  grep -qF 'GIT_AUTHOR_EMAIL=profile-email' "$SETUP_HOST_RECORD"
  grep -qF 'GIT_COMMITTER_NAME=Profile User' "$SETUP_HOST_RECORD"
  grep -qF 'GIT_COMMITTER_EMAIL=profile-email' "$SETUP_HOST_RECORD"
  grep -qF 'PROFILE_GIT=<config><--local user.name Profile User>' "$GIT_RECORD"
  grep -qF 'PROFILE_GIT=<config><--local user.email profile-email>' "$GIT_RECORD"
  [[ "$output" == *"only in the private profile"* ]]
  run grep -qF 'GLOBAL_GIT_WRITE=' "$GIT_RECORD"
  [ "$status" -ne 0 ]
}

@test "missing identity stops non-interactive setup before cloning" {
  SETUP_ARGS=(--new --skip-apps)
  run_setup \
    FAKE_GIT_IDENTITY_MISSING=1 \
    GIT_AUTHOR_NAME= \
    GIT_AUTHOR_EMAIL=
  [ "$status" -ne 0 ]
  [[ "$output" == *"required for local profile commits"* ]]
  [ ! -e "$GIT_RECORD" ]
}

@test "new journey writes repeatable application choices before preflight" {
  SETUP_ARGS=(
    --new
    --cask firefox
    --cask ghostty
    --nix-package ripgrep
    --mas-app "Notability=360593530"
  )
  run_setup
  [ "$status" -eq 0 ]

  grep -qF 'ARGS=<add><--cask><firefox>' "$APPS_RECORD"
  grep -qF 'ARGS=<add><--cask><ghostty>' "$APPS_RECORD"
  grep -qF 'ARGS=<add><--nix><ripgrep>' "$APPS_RECORD"
  grep -qF 'ARGS=<add><--mas><Notability><360593530>' "$APPS_RECORD"
  grep -qF 'PROFILE_GIT=<add><apps/>' "$GIT_RECORD"
  grep -qF 'PROFILE_GIT=<commit><-m Choose applications>' "$GIT_RECORD"
  grep -qF 'ARGS=<--host><test-mac>' "$BOOTSTRAP_RECORD"
  [[ "$output" == *"Saved application choices in the private profile"* ]]
}

@test "new journey preserves a full App Store URL including query parameters" {
  app_url="https://apps.apple.com/us/app/example/id1234567890?mt=12&source=installer"
  SETUP_ARGS=(
    --new
    --mas-app "Example App=$app_url"
  )
  run_setup
  [ "$status" -eq 0 ]

  grep -qF "ARGS=<add><--mas><Example App><$app_url>" "$APPS_RECORD"
}

@test "skip-apps keeps a new profile application-neutral" {
  SETUP_ARGS=(--new --skip-apps)
  run_setup
  [ "$status" -eq 0 ]
  [ ! -e "$APPS_RECORD" ]
  run grep -qF 'PROFILE_GIT=<commit><-m Choose applications>' "$GIT_RECORD"
  [ "$status" -ne 0 ]
}

@test "restore rejects application options before cloning" {
  SETUP_ARGS=(--restore owner/private-profile --cask firefox)
  run_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"application selection is only valid with --new"* ]]
  [ ! -e "$GIT_RECORD" ]
}

@test "skip-apps cannot contradict explicit selections" {
  SETUP_ARGS=(--new --skip-apps --nix-package jq)
  run_setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"--skip-apps cannot be combined"* ]]
  [ ! -e "$GIT_RECORD" ]
}

@test "a failed application choice restores generated files and stops preflight" {
  SETUP_ARGS=(--new --cask firefox --nix-package invalid)
  run_setup FAKE_APPS_FAIL_ON="--nix invalid"
  [ "$status" -ne 0 ]
  [[ "$output" == *"generated apps/ files were restored"* ]]
  grep -qF 'PROFILE_GIT=<restore><--worktree -- apps/>' "$GIT_RECORD"
  [ ! -e "$BOOTSTRAP_RECORD" ]
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
