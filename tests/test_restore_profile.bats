#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  RESTORE="$REPO_ROOT/scripts/bin/restore-profile"
  TMP="$(mktemp -d -t dotfiles_restore_test.XXXXXX)"
  STUB_BIN="$TMP/bin"
  PROFILE="$TMP/profile"
  mkdir -p "$STUB_BIN"

  command -v jq >/dev/null 2>&1 || skip "jq is required"

  cat > "$STUB_BIN/nix" <<'EOF'
#!/bin/sh
if [ -n "${NIX_CALLED_FILE:-}" ]; then
  : > "$NIX_CALLED_FILE"
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
EOF
  chmod +x "$STUB_BIN/nix"
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

  cat > "$PROFILE/flake.nix" <<'EOF'
{
  outputs = { ... }: {
    darwinConfigurations = { };
  };
}
EOF

  cat > "$PROFILE/flake.lock" <<EOF
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
EOF

  printf '{ }\n' > "$PROFILE/hosts/mac-one.nix"
  printf '{ }\n' > "$PROFILE/hosts/mac-two.nix"
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm init
}

run_restore() {
  run env PATH="$STUB_BIN:$PATH" \
          STUB_HOSTS_JSON="${STUB_HOSTS_JSON:-[\"mac-one\",\"mac-two\"]}" \
          NIX_CALLED_FILE="${NIX_CALLED_FILE:-}" \
          DOTFILES_RESTORE_HOST="${DOTFILES_RESTORE_HOST:-mac-one}" \
          bash "$RESTORE" --profile "$PROFILE" "$@"
}

@test "preflight reports the committed profile, host, framework, and unchanged lock" {
  make_profile
  before="$(git hash-object "$PROFILE/flake.lock")"

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
}

@test "preflight preserves a custom framework source from the profile lock" {
  make_profile alice custom-framework deadbeefcafebabe

  run_restore
  assert_success
  assert_output_contains "Framework input:    github:alice/custom-framework"
  assert_output_contains "Pinned revision:    deadbeefcafebabe"
  [[ "$output" != *"github:ucod3/dotfiles"* ]]
}

@test "an unknown hostname fails without selecting another host" {
  make_profile
  DOTFILES_RESTORE_HOST="new-mac"

  run_restore
  [ "$status" -eq 2 ]
  assert_output_contains "Host:               new-mac"
  assert_output_contains "Available hosts:    mac-one, mac-two"
  assert_output_contains "No configuration exists for host 'new-mac'."
  assert_output_contains "No host was selected automatically."
}

@test "a dirty profile stops before Nix evaluation" {
  make_profile
  printf 'unreviewed\n' > "$PROFILE/pending.txt"
  NIX_CALLED_FILE="$TMP/nix-called"

  run_restore
  assert_failure
  assert_output_contains "profile has uncommitted changes"
  assert_output_contains "?? pending.txt"
  [ ! -e "$NIX_CALLED_FILE" ]
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

@test "json output is a stable machine-readable plan" {
  make_profile

  run_restore --json
  assert_success
  [ "$(jq -r '.status' <<<"$output")" = "ready" ]
  [ "$(jq -r '.host' <<<"$output")" = "mac-one" ]
  [ "$(jq -r '.framework' <<<"$output")" = "github:ucod3/dotfiles" ]
  [ "$(jq -r '.lockChanged' <<<"$output")" = "false" ]
  [ "$(jq -r '.activationPerformed' <<<"$output")" = "false" ]
  [ "$(jq -r '.availableHosts | join(",")' <<<"$output")" = "mac-one,mac-two" ]
}

@test "unknown options are rejected" {
  make_profile

  run_restore --activate
  assert_failure
  assert_output_contains "unknown option: --activate"
}

@test "the framework flake exports the restore application" {
  run grep -q 'restore = {' "$REPO_ROOT/flake.nix"
  assert_success
  run grep -q 'dotfiles-restore' "$REPO_ROOT/flake.nix"
  assert_success
}
