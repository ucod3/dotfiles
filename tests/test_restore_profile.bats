#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  RESTORE="$REPO_ROOT/scripts/bin/restore-profile"
  TMP="$(mktemp -d -t dotfiles_restore_test.XXXXXX)"
  STUB_BIN="$TMP/bin"
  PROFILE="$TMP/profile"
  DARWIN_CALLED_FILE="$TMP/darwin-called"
  SUDO_CALLED_FILE="$TMP/sudo-called"
  mkdir -p "$STUB_BIN"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  cat > "$STUB_BIN/nix" <<'STUB_NIX'
#!/bin/sh
if [ -n "${NIX_CALLED_FILE:-}" ]; then
  : > "$NIX_CALLED_FILE"
fi
if [ -n "${NIX_ENV_FILE:-}" ]; then
  printf 'DOTFILES_LOCAL=%s\n' "${DOTFILES_LOCAL:-}" > "$NIX_ENV_FILE"
fi
case "$*" in
  *darwinConfigurations*)
    printf '%s\n' "${STUB_HOSTS_JSON:-[\"mac-one\"]}"
    ;;
  *)
    echo "unexpected nix invocation: $*" >&2
    exit 64
    ;;
esac
STUB_NIX

  cat > "$STUB_BIN/darwin-rebuild" <<'STUB_DARWIN'
#!/bin/sh
if [ -n "${DARWIN_CALLED_FILE:-}" ]; then
  {
    printf 'DOTFILES_LOCAL=%s\n' "${DOTFILES_LOCAL:-}"
    printf 'ARGS='
    printf '<%s>' "$@"
    printf '\n'
  } > "$DARWIN_CALLED_FILE"
fi
exit "${DARWIN_EXIT_STATUS:-0}"
STUB_DARWIN

  cat > "$STUB_BIN/sudo" <<'STUB_SUDO'
#!/bin/sh
if [ -n "${SUDO_CALLED_FILE:-}" ]; then
  printf '<%s>' "$@" > "$SUDO_CALLED_FILE"
fi
exec "$@"
STUB_SUDO

  chmod +x "$STUB_BIN/nix" "$STUB_BIN/darwin-rebuild" "$STUB_BIN/sudo"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

make_profile() {
  local owner="${1:-ucod3}"
  local repo="${2:-dotfiles}"
  local rev="${3:-0123456789abcdef}"

  mkdir -p "$PROFILE/hosts"
  git -C "$PROFILE" init -q
  git -C "$PROFILE" config user.name Test
  git -C "$PROFILE" config user.email test@example.com

  cat > "$PROFILE/flake.nix" <<'EOF_FLAKE'
{
  outputs = { ... }: {
    darwinConfigurations = { };
  };
}
EOF_FLAKE

  cat > "$PROFILE/flake.lock" <<EOF_LOCK
{
  "nodes": {
    "dotfiles": {
      "locked": {
        "lastModified": 1,
        "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "owner": "$owner",
        "repo": "$repo",
        "rev": "$rev",
        "type": "github"
      },
      "original": {
        "owner": "$owner",
        "repo": "$repo",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "dotfiles": "dotfiles"
      }
    }
  },
  "root": "root",
  "version": 7
}
EOF_LOCK

  printf '{ }\n' > "$PROFILE/hosts/mac-one.nix"
  printf '{ }\n' > "$PROFILE/hosts/mac-two.nix"
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm init
}

run_restore() {
  run env PATH="$STUB_BIN:$PATH" \
          STUB_HOSTS_JSON="${STUB_HOSTS_JSON:-[\"mac-one\",\"mac-two\"]}" \
          NIX_CALLED_FILE="${NIX_CALLED_FILE:-}" \
          NIX_ENV_FILE="${NIX_ENV_FILE:-}" \
          DARWIN_CALLED_FILE="${DARWIN_CALLED_FILE:-}" \
          DARWIN_EXIT_STATUS="${DARWIN_EXIT_STATUS:-0}" \
          SUDO_CALLED_FILE="${SUDO_CALLED_FILE:-}" \
          DOTFILES_RESTORE_HOST="${DOTFILES_RESTORE_HOST:-mac-one}" \
          bash "$RESTORE" --profile "$PROFILE" "$@"
}

@test "preflight reports the committed profile, host, framework, and unchanged lock" {
  make_profile
  before="$(git hash-object "$PROFILE/flake.lock")"
  NIX_ENV_FILE="$TMP/nix-env"

  run_restore
  assert_success
  assert_output_contains "Profile:            $PROFILE"
  assert_output_contains "Profile remote:     <none>"
  assert_output_contains "Host:               mac-one"
  assert_output_contains "Available hosts:    mac-one, mac-two"
  assert_output_contains "Framework input:    github:ucod3/dotfiles"
  assert_output_contains "Pinned revision:    0123456789abcdef"
  assert_output_contains "Lock file:          $PROFILE/flake.lock (unchanged)"
  assert_output_contains "Activation:         not performed"
  [ "$before" = "$(git hash-object "$PROFILE/flake.lock")" ]
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
  grep -qF "DOTFILES_LOCAL=$PROFILE" "$NIX_ENV_FILE"
  [ ! -e "$DARWIN_CALLED_FILE" ]
}

@test "preflight preserves a custom framework source from the profile lock" {
  make_profile alice custom-framework deadbeefcafebabe

  run_restore
  assert_success
  assert_output_contains "Framework input:    github:alice/custom-framework"
  assert_output_contains "Pinned revision:    deadbeefcafebabe"
  [[ "$output" != *"github:ucod3/dotfiles"* ]]
}

@test "an unknown hostname blocks activation without selecting another host" {
  make_profile
  DOTFILES_RESTORE_HOST="new-mac"

  run_restore --activate --yes
  [ "$status" -eq 2 ]
  assert_output_contains "Host:               new-mac"
  assert_output_contains "Available hosts:    mac-one, mac-two"
  assert_output_contains "Activation:         blocked (host missing)"
  assert_output_contains "No configuration exists for host 'new-mac'."
  assert_output_contains "No host was selected automatically."
  [ ! -e "$DARWIN_CALLED_FILE" ]
  [ ! -e "$SUDO_CALLED_FILE" ]
}

@test "a dirty profile stops before Nix evaluation or activation" {
  make_profile
  printf 'unreviewed\n' > "$PROFILE/pending.txt"
  NIX_CALLED_FILE="$TMP/nix-called"

  run_restore --activate --yes
  assert_failure
  assert_output_contains "profile has uncommitted changes"
  assert_output_contains "?? pending.txt"
  [ ! -e "$NIX_CALLED_FILE" ]
  [ ! -e "$DARWIN_CALLED_FILE" ]
}

@test "a missing lock stops before evaluation" {
  make_profile
  rm "$PROFILE/flake.lock"
  NIX_CALLED_FILE="$TMP/nix-called"

  run_restore
  assert_failure
  assert_output_contains "profile is missing flake.lock"
  [ ! -e "$NIX_CALLED_FILE" ]
}

@test "json output is a stable machine-readable preflight plan" {
  make_profile

  run_restore --json
  assert_success
  [ "$(jq -r '.status' <<<"$output")" = "ready" ]
  [ "$(jq -r '.host' <<<"$output")" = "mac-one" ]
  [ "$(jq -r '.framework' <<<"$output")" = "github:ucod3/dotfiles" ]
  [ "$(jq -r '.lockChanged' <<<"$output")" = "false" ]
  [ "$(jq -r '.activationRequested' <<<"$output")" = "false" ]
  [ "$(jq -r '.activationPerformed' <<<"$output")" = "false" ]
  [ "$(jq -r '.availableHosts | join(",")' <<<"$output")" = "mac-one,mac-two" ]
}

@test "explicit activation runs the validated host with the unchanged lock" {
  make_profile
  before="$(git hash-object "$PROFILE/flake.lock")"

  run_restore --activate --yes
  assert_success
  assert_output_contains "Activation:         requested (not yet performed)"
  assert_output_contains "Activation command:"
  assert_output_contains "Activation complete. flake.lock is unchanged."
  grep -qF "DOTFILES_LOCAL=$PROFILE" "$DARWIN_CALLED_FILE"
  grep -qF "ARGS=<switch><--flake><$PROFILE#mac-one><--impure><--no-write-lock-file>" "$DARWIN_CALLED_FILE"
  grep -qF '<env>' "$SUDO_CALLED_FILE"
  [ "$before" = "$(git hash-object "$PROFILE/flake.lock")" ]
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
}

@test "activation requires a terminal or the separate yes flag" {
  make_profile

  run_restore --activate
  assert_failure
  assert_output_contains "activation needs an interactive terminal"
  assert_output_contains "rerun with --yes only after reviewing the plan"
  [ ! -e "$DARWIN_CALLED_FILE" ]
}

@test "a failed activation returns failure without changing the lock" {
  make_profile
  before="$(git hash-object "$PROFILE/flake.lock")"
  DARWIN_EXIT_STATUS=42

  run_restore --activate --yes
  assert_failure
  assert_output_contains "activation command failed"
  [ -e "$DARWIN_CALLED_FILE" ]
  [ "$before" = "$(git hash-object "$PROFILE/flake.lock")" ]
}

@test "activation flags have deliberate combinations" {
  make_profile

  run_restore --activate --json
  assert_failure
  assert_output_contains "--json is preflight-only"
  [ ! -e "$DARWIN_CALLED_FILE" ]

  run_restore --yes
  assert_failure
  assert_output_contains "--yes is only valid with --activate"
  [ ! -e "$DARWIN_CALLED_FILE" ]
}

@test "unknown options are rejected" {
  make_profile

  run_restore --explode
  assert_failure
  assert_output_contains "unknown option: --explode"
}

@test "the framework flake exports restore with pinned darwin-rebuild" {
  run grep -q 'restore = {' "$REPO_ROOT/flake.nix"
  assert_success
  run grep -q 'dotfiles-restore' "$REPO_ROOT/flake.nix"
  assert_success
  run grep -q 'nix-darwin.packages.${system}.darwin-rebuild' "$REPO_ROOT/flake.nix"
  assert_success
}
