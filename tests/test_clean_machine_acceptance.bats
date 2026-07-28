#!/usr/bin/env bats

# Contract-level clean-machine proof.
#
# This test deliberately uses the real profile generator, real Git commits, and
# the public setup.sh restore router. macOS prerequisites and Nix execution are
# command doubles, so CI never installs Nix or activates a machine.

setup() {
  load 'bats_helper'

  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  SETUP="$REPO_ROOT/setup.sh"
  REAL_GIT="$(command -v git)"

  TMP="$(mktemp -d -t clean_machine_acceptance.XXXXXX)"
  TMP="$(cd "$TMP" && pwd -P)"
  MAC_A_HOME="$TMP/mac-a"
  MAC_B_HOME="$TMP/mac-b"
  FRAMEWORK_A="$MAC_A_HOME/dotfiles"
  PROFILE_A="$MAC_A_HOME/dotfiles-private"
  PROFILE_B="$MAC_B_HOME/dotfiles-private"
  PRIVATE_REMOTE="$TMP/dotfiles-private.git"
  FAKE_BIN="$TMP/bin"
  NIX_RECORD="$TMP/nix-record"
  LOCK_HASH_BEFORE="$TMP/lock-hash-before"

  mkdir -p "$MAC_A_HOME" "$MAC_B_HOME" "$FAKE_BIN"

  # Keep every Git identity and default-branch decision inside the fixture.
  export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
  "$REAL_GIT" config --file "$GIT_CONFIG_GLOBAL" user.name "Acceptance Test"
  "$REAL_GIT" config --file "$GIT_CONFIG_GLOBAL" user.email "acceptance@example.invalid"
  "$REAL_GIT" config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

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

  # setup.sh receives a normal GitHub-shaped framework URL, while this wrapper
  # maps that one clone to the checked-out repository. Every other Git command
  # is real, including private-profile init, commit, push, and restore clone.
  cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" \
   && "${2:-}" == "https://github.com/example/framework.git" ]]; then
  exec "$REAL_GIT" clone "$TEST_FRAMEWORK_SOURCE" "${3:?missing clone destination}"
fi
exec "$REAL_GIT" "$@"
EOF

  # The lock fixture carries an exact framework revision. `nix run` records the
  # profile-owned preflight handoff and changes nothing.
  cat > "$FAKE_BIN/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "flake lock")
    cat > flake.lock <<'LOCK'
{
  "nodes": {
    "dotfiles": {
      "locked": {
        "lastModified": 1,
        "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "owner": "example",
        "repo": "framework",
        "rev": "0123456789abcdef0123456789abcdef01234567",
        "type": "github"
      },
      "original": {
        "owner": "example",
        "repo": "framework",
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
LOCK
    ;;
  "run .#restore")
    {
      printf 'PWD=%s\n' "$PWD"
      printf 'ARGS='
      printf '<%s>' "$@"
      printf '\n'
    } >> "$NIX_RECORD"
    ;;
  *)
    exit 0
    ;;
esac
EOF

  chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/xcode-select" \
    "$FAKE_BIN/git" "$FAKE_BIN/nix"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_public_setup() {
  local home_dir="$1"
  shift

  run env HOME="$home_dir" \
          PATH="$FAKE_BIN:$PATH" \
          REAL_GIT="$REAL_GIT" \
          TEST_FRAMEWORK_SOURCE="$REPO_ROOT" \
          NIX_RECORD="$NIX_RECORD" \
          GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" \
          "$@"
}

@test "a committed private profile survives a two-Mac create and restore round trip" {
  # Mac A: use the public new-profile journey and the real framework generator.
  run_public_setup "$MAC_A_HOME" \
    env DOTFILES_FRAMEWORK_DIR="$FRAMEWORK_A" \
        DOTFILES_PROFILE_DIR="$PROFILE_A" \
        DOTFILES_INSTALL_HOST="mac-one" \
        DOTFILES_INSTALL_USER="alice" \
        bash "$SETUP" \
          --new \
          --framework example/framework \
          --cask firefox \
          --cask ghostty \
          --nix-package jq
  [ "$status" -eq 0 ]

  [[ "$output" == *"Creating a readable private profile for mac-one"* ]]
  [[ "$output" == *"exists only on this Mac"* ]]
  [ -x "$PROFILE_A/bootstrap" ]
  [ -f "$PROFILE_A/hosts/mac-one.nix" ]
  [ -f "$PROFILE_A/apps/homebrew-casks.nix" ]
  [ -f "$PROFILE_A/apps/nix-packages.nix" ]
  [ -f "$PROFILE_A/flake.lock" ]
  grep -qF 'github:example/framework' "$PROFILE_A/flake.nix"
  grep -qF "PWD=$PROFILE_A" "$NIX_RECORD"
  grep -qF "<--host><mac-one>" "$NIX_RECORD"
  run grep -qF '<--activate>' "$NIX_RECORD"
  [ "$status" -ne 0 ]
  grep -qF '"firefox"' "$PROFILE_A/apps/homebrew-casks.nix"
  grep -qF '"ghostty"' "$PROFILE_A/apps/homebrew-casks.nix"
  grep -qF 'pkgs.jq' "$PROFILE_A/apps/nix-packages.nix"
  [ "$($REAL_GIT -C "$PROFILE_A" log -1 --format=%s)" = "Choose applications" ]
  [ -z "$($REAL_GIT -C "$PROFILE_A" status --short)" ]

  # Publishing the private repository is what turns the local profile into a
  # recoverable backup. Use a real bare remote and real push.
  "$REAL_GIT" init --bare "$PRIVATE_REMOTE" >/dev/null
  "$REAL_GIT" -C "$PROFILE_A" remote add origin "$PRIVATE_REMOTE"
  "$REAL_GIT" -C "$PROFILE_A" push -u origin HEAD >/dev/null

  "$REAL_GIT" -C "$PROFILE_A" hash-object flake.lock > "$LOCK_HASH_BEFORE"
  source_head="$($REAL_GIT -C "$PROFILE_A" rev-parse HEAD)"
  source_tree="$($REAL_GIT -C "$PROFILE_A" rev-parse HEAD^{tree})"

  # Mac B: restore through the public router. It clones only the private profile
  # and delegates to that clone's bootstrap in preflight mode.
  run_public_setup "$MAC_B_HOME" \
    env DOTFILES_PROFILE_DIR="$PROFILE_B" \
        DOTFILES_INSTALL_HOST="mac-one" \
        bash "$SETUP" --restore "$PRIVATE_REMOTE"
  [ "$status" -eq 0 ]

  [[ "$output" == *"Cloning private profile repository"* ]]
  [[ "$output" == *"Invoking the profile-owned restore contract"* ]]
  [[ "$output" == *"Profile journey completed"* ]]
  [ ! -e "$MAC_B_HOME/dotfiles" ]

  [ "$($REAL_GIT -C "$PROFILE_B" rev-parse HEAD)" = "$source_head" ]
  [ "$($REAL_GIT -C "$PROFILE_B" rev-parse HEAD^{tree})" = "$source_tree" ]
  [ -z "$($REAL_GIT -C "$PROFILE_B" status --short)" ]
  cmp "$PROFILE_A/flake.lock" "$PROFILE_B/flake.lock"
  cmp "$PROFILE_A/apps/homebrew-casks.nix" "$PROFILE_B/apps/homebrew-casks.nix"
  cmp "$PROFILE_A/apps/nix-packages.nix" "$PROFILE_B/apps/nix-packages.nix"
  grep -qF '"firefox"' "$PROFILE_B/apps/homebrew-casks.nix"
  grep -qF 'pkgs.jq' "$PROFILE_B/apps/nix-packages.nix"
  [ "$($REAL_GIT -C "$PROFILE_B" hash-object flake.lock)" = "$(cat "$LOCK_HASH_BEFORE")" ]

  # Both journeys reached profile-owned preflight, and neither inferred live
  # activation. The restore clone used the selected host unchanged.
  [ "$(grep -c '^PWD=' "$NIX_RECORD")" -eq 2 ]
  grep -qF "PWD=$PROFILE_B" "$NIX_RECORD"
  [ "$(grep -c '<--host><mac-one>' "$NIX_RECORD")" -eq 2 ]
  run grep -qF '<--activate>' "$NIX_RECORD"
  [ "$status" -ne 0 ]
}
