#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  SETUP_HOST="$REPO_ROOT/scripts/bin/setup-private-host"
  GENERATOR="$REPO_ROOT/scripts/lib/generate-private-profile.sh"
  TMP="$(mktemp -d -t private_first_run.XXXXXX)"
  PRIVATE="$TMP/dotfiles-private"
  FAKE_BIN="$TMP/bin"
  mkdir -p "$FAKE_BIN"

  cat > "$FAKE_BIN/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-} ${2:-}" == "flake lock" ]]; then
  printf '{}\n' > flake.lock
  exit 0
fi
echo "unexpected nix invocation: $*" >&2
exit 1
EOF
  chmod +x "$FAKE_BIN/nix"

  export GIT_AUTHOR_NAME="Test User"
  export GIT_AUTHOR_EMAIL="test@example.com"
  export GIT_COMMITTER_NAME="Test User"
  export GIT_COMMITTER_EMAIL="test@example.com"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_setup() {
  run env \
    HOME="$TMP/home" \
    PATH="$FAKE_BIN:$PATH" \
    DOTFILES_ROOT="$REPO_ROOT" \
    DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
    bash "$SETUP_HOST" "$@"
}

@test "fresh setup creates the readable modular profile and tracks upstream" {
  mkdir -p "$TMP/home"

  run_setup --host test-mac --user alice
  [ "$status" -eq 0 ]

  [ -f "$PRIVATE/README.md" ]
  [ -f "$PRIVATE/apps/homebrew-casks.nix" ]
  [ -f "$PRIVATE/macos/default.nix" ]
  [ -f "$PRIVATE/home/default.nix" ]
  [ -f "$PRIVATE/home.nix" ]
  [ -f "$PRIVATE/hosts/test-mac.nix" ]
  grep -q 'dotfiles.url = "github:ucod3/dotfiles"' "$PRIVATE/flake.nix"
  grep -qF '../apps' "$PRIVATE/hosts/test-mac.nix"
  grep -qF '../macos' "$PRIVATE/hosts/test-mac.nix"
  grep -qF '../home' "$PRIVATE/hosts/test-mac.nix"
  [[ "$output" == *"Using public framework: github:ucod3/dotfiles"* ]]
  [[ "$output" != *"Enter YOUR fork"* ]]
  [ "$(git -C "$PRIVATE" rev-list --count HEAD)" -eq 1 ]
}

@test "an explicit fork remains an advanced first-run override" {
  mkdir -p "$TMP/home"

  run_setup --host test-mac --user alice --fork alice/dotfiles
  [ "$status" -eq 0 ]

  grep -q 'dotfiles.url = "github:alice/dotfiles"' "$PRIVATE/flake.nix"
  [[ "$output" == *"Using custom framework: github:alice/dotfiles"* ]]
}

@test "second Mac added to a modular profile uses focused module imports" {
  mkdir -p "$TMP/home"
  bash "$GENERATOR" \
    --root "$PRIVATE" \
    --host first-mac \
    --user alice >/dev/null
  git init "$PRIVATE" >/dev/null
  git -C "$PRIVATE" add .
  git -C "$PRIVATE" commit -m initial >/dev/null

  run_setup --host second-mac --user alice
  [ "$status" -eq 0 ]

  [ -f "$PRIVATE/hosts/first-mac.nix" ]
  [ -f "$PRIVATE/hosts/second-mac.nix" ]
  grep -qF '../apps' "$PRIVATE/hosts/second-mac.nix"
  grep -qF '../macos' "$PRIVATE/hosts/second-mac.nix"
  grep -qF '../home' "$PRIVATE/hosts/second-mac.nix"
  git -C "$PRIVATE" diff --cached --name-only | grep -q '^hosts/second-mac.nix$'
}

@test "second Mac added to a legacy profile keeps the legacy host shape" {
  mkdir -p "$TMP/home" "$PRIVATE/hosts"
  cat > "$PRIVATE/flake.nix" <<'EOF'
{
  outputs = { ... }: {
    # Compatibility fixture: host discovery is the contract under test.
    hostNames = builtins.attrNames (builtins.readDir ./hosts);
  };
}
EOF
  cat > "$PRIVATE/home.nix" <<'EOF'
{ config, ... }:
{
  home.file = {
    # dot-adopt:entries — new mappings are inserted directly above this line.
  };
}
EOF
  git init "$PRIVATE" >/dev/null
  git -C "$PRIVATE" add .
  git -C "$PRIVATE" commit -m initial >/dev/null

  run_setup --host legacy-mac --user alice
  [ "$status" -eq 0 ]

  grep -qF '../home.nix' "$PRIVATE/hosts/legacy-mac.nix"
  run grep -qF '../apps' "$PRIVATE/hosts/legacy-mac.nix"
  [ "$status" -ne 0 ]
}

@test "fresh setup refuses a non-empty destination without a flake" {
  mkdir -p "$TMP/home" "$PRIVATE"
  printf 'keep me\n' > "$PRIVATE/personal.txt"

  run_setup --host test-mac --user alice
  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to overwrite"* ]]
  [ "$(cat "$PRIVATE/personal.txt")" = "keep me" ]
  [ ! -e "$PRIVATE/flake.nix" ]
}
