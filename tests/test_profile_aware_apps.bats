#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  APPS="$REPO_ROOT/scripts/bin/apps"
  GENERATOR="$REPO_ROOT/scripts/lib/generate-private-profile.sh"
  TMP="$(mktemp -d -t profile_apps.XXXXXX)"
  PRIVATE="$TMP/dotfiles-private"
  FAKE_HOME="$TMP/home"
  STUB_BIN="$TMP/bin"
  mkdir -p "$FAKE_HOME" "$STUB_BIN"

  bash "$GENERATOR" \
    --root "$PRIVATE" \
    --host test-mac \
    --user alice >/dev/null

  # Only Firefox is auto-detected as a cask. jq is a formula, and unknown names
  # fail both lookups. Explicit --cask/--nix/--mas paths do not need this stub.
  cat > "$STUB_BIN/brew" <<'EOF'
#!/bin/sh
if [ "${1:-} ${2:-} ${3:-}" = "info --cask firefox" ]; then
  exit 0
fi
if [ "${1:-} ${2:-}" = "info jq" ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$STUB_BIN/brew"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_modular_apps() {
  run env HOME="$FAKE_HOME" \
          PATH="$STUB_BIN:$PATH" \
          DOTFILES_ROOT="$REPO_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
          DOTFILES_LOCAL="$TMP/unused-local" \
          DOTFILES_APPS_SKIP_VALIDATE=1 \
          "$APPS" "$@"
}

run_legacy_apps() {
  run env HOME="$FAKE_HOME" \
          PATH="$STUB_BIN:$PATH" \
          DOTFILES_ROOT="$REPO_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$TMP/legacy-private" \
          DOTFILES_LOCAL="$TMP/legacy-local" \
          DOTFILES_APPS_SKIP_VALIDATE=1 \
          "$APPS" "$@"
}

@test "help identifies the modular private profile without undefined helpers" {
  run_modular_apps
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active profile:"* ]]
  [[ "$output" == *"(modular)"* ]]
  [[ "$output" != *"command not found"* ]]
}

@test "list reads all three focused modular application files" {
  run_modular_apps add --cask firefox
  [ "$status" -eq 0 ]
  run_modular_apps add --nix jq
  [ "$status" -eq 0 ]
  run_modular_apps add --mas "Visual Studio Code" 12345
  [ "$status" -eq 0 ]

  run_modular_apps list
  [ "$status" -eq 0 ]
  [[ "$output" == *"firefox"* ]]
  [[ "$output" == *"jq"* ]]
  [[ "$output" == *"Visual Studio Code  (ID: 12345)"* ]]
  [[ "$output" == *"apps/homebrew-casks.nix"* ]]
  [[ "$output" == *"apps/nix-packages.nix"* ]]
  [[ "$output" == *"apps/mac-app-store.nix"* ]]
  [[ "$output" != *"# Notability"* ]]
}

@test "explicit additions write ordinary readable Nix to one owning file" {
  run_modular_apps add --cask firefox
  [ "$status" -eq 0 ]
  [[ "$output" == *'Equivalent manual change:'* ]]
  [[ "$output" == *'Add "firefox"'* ]]
  grep -qF '  "firefox"' "$PRIVATE/apps/homebrew-casks.nix"

  run_modular_apps add --nix jq
  [ "$status" -eq 0 ]
  grep -qF '  pkgs.jq' "$PRIVATE/apps/nix-packages.nix"

  run_modular_apps add --mas "Visual Studio Code" 12345
  [ "$status" -eq 0 ]
  grep -qF '  "Visual Studio Code" = 12345;' "$PRIVATE/apps/mac-app-store.nix"

  run grep -R -F '"firefox"' "$PRIVATE/apps/nix-packages.nix" \
    "$PRIVATE/apps/mac-app-store.nix"
  [ "$status" -ne 0 ]
}

@test "the ordinary add form auto-detects a Homebrew cask" {
  run_modular_apps add firefox
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found as a Homebrew cask"* ]]
  grep -qF '"firefox"' "$PRIVATE/apps/homebrew-casks.nix"
}

@test "a Homebrew formula is not guessed to be the same Nix attribute" {
  run_modular_apps add jq
  [ "$status" -eq 0 ]
  [[ "$output" == *"Prefer Nix when available"* ]]
  [[ "$output" == *"dot apps add --nix <nixpkgs-attribute>"* ]]
  run grep -qF 'pkgs.jq' "$PRIVATE/apps/nix-packages.nix"
  [ "$status" -ne 0 ]
}

@test "duplicate additions leave one declaration" {
  run_modular_apps add --cask firefox
  [ "$status" -eq 0 ]
  run_modular_apps add --cask firefox
  [ "$status" -eq 0 ]
  [[ "$output" == *"already declared"* ]]

  run grep -c '^[[:space:]]*"firefox"[[:space:]]*$' \
    "$PRIVATE/apps/homebrew-casks.nix"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "remove changes only the owning modular file and keeps cleanup safe" {
  run_modular_apps add --cask firefox
  [ "$status" -eq 0 ]
  run_modular_apps add --nix jq
  [ "$status" -eq 0 ]
  run_modular_apps add --mas "Visual Studio Code" 12345
  [ "$status" -eq 0 ]

  run_modular_apps remove firefox
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cleanup remains \"none\""* ]]
  run grep -qE '^[[:space:]]*"firefox"[[:space:]]*$' \
    "$PRIVATE/apps/homebrew-casks.nix"
  [ "$status" -ne 0 ]
  grep -qF 'pkgs.jq' "$PRIVATE/apps/nix-packages.nix"

  run_modular_apps remove "Visual Studio Code"
  [ "$status" -eq 0 ]
  run grep -qF '"Visual Studio Code" = 12345;' \
    "$PRIVATE/apps/mac-app-store.nix"
  [ "$status" -ne 0 ]
}

@test "advanced hand-authored Nix is never parsed and rewritten" {
  printf '%s\n' \
    '# owner-authored expression' \
    'with builtins;' \
    '[ "firefox" ]' > "$PRIVATE/apps/homebrew-casks.nix"
  before="$(shasum "$PRIVATE/apps/homebrew-casks.nix")"

  run_modular_apps add --cask ghostty
  [ "$status" -ne 0 ]
  [[ "$output" == *"will not parse or rewrite advanced Nix"* ]]
  [ "$(shasum "$PRIVATE/apps/homebrew-casks.nix")" = "$before" ]
}

@test "legacy profiles continue to use the compatibility apps file" {
  mkdir -p "$TMP/legacy-private" "$TMP/legacy-local"

  run_legacy_apps add --cask firefox
  [ "$status" -eq 0 ]
  [[ "$output" == *"legacy compatibility path"* ]]
  grep -qF '"firefox"' "$TMP/legacy-local/apps.nix"
  [ ! -e "$TMP/legacy-private/apps" ]

  run_legacy_apps list
  [ "$status" -eq 0 ]
  [[ "$output" == *"legacy compatibility"* ]]
  [[ "$output" == *"firefox"* ]]

  run_legacy_apps remove firefox
  [ "$status" -eq 0 ]
  run grep -qF '"firefox"' "$TMP/legacy-local/apps.nix"
  [ "$status" -ne 0 ]
}
