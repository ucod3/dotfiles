#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  GENERATOR="$REPO_ROOT/scripts/lib/generate-private-profile.sh"
  DOT_ADOPT="$REPO_ROOT/scripts/bin/dot-adopt"
  TMP="$(mktemp -d -t private_profile.XXXXXX)"
  PRIVATE="$TMP/dotfiles-private"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_generator() {
  run bash "$GENERATOR" \
    --root "$PRIVATE" \
    --host test-mac \
    --user alice \
    "$@"
}

@test "fresh profile has an obvious responsibility-based structure" {
  run_generator
  [ "$status" -eq 0 ]

  [ -f "$PRIVATE/README.md" ]
  [ -x "$PRIVATE/bootstrap" ]
  [ -f "$PRIVATE/flake.nix" ]
  [ -f "$PRIVATE/identity.nix" ]
  [ -f "$PRIVATE/hosts/test-mac.nix" ]
  [ -f "$PRIVATE/apps/default.nix" ]
  [ -f "$PRIVATE/apps/homebrew-casks.nix" ]
  [ -f "$PRIVATE/apps/nix-packages.nix" ]
  [ -f "$PRIVATE/apps/mac-app-store.nix" ]
  [ -f "$PRIVATE/macos/default.nix" ]
  [ -f "$PRIVATE/home.nix" ]
  [ -f "$PRIVATE/home/default.nix" ]
  [ -d "$PRIVATE/home/files" ]
  [[ "$output" == *"Restore:   ./bootstrap (non-destructive preflight)"* ]]
}

@test "ordinary users consume the upstream framework without a fork" {
  run_generator
  [ "$status" -eq 0 ]

  grep -q 'dotfiles.url = "github:ucod3/dotfiles"' "$PRIVATE/flake.nix"
  [[ "$output" == *"Framework: github:ucod3/dotfiles"* ]]
}

@test "an explicit framework fork remains an advanced option" {
  run_generator --framework github:alice/my-framework
  [ "$status" -eq 0 ]

  grep -q 'dotfiles.url = "github:alice/my-framework"' "$PRIVATE/flake.nix"
  grep -qF 'github:alice/my-framework' "$PRIVATE/README.md"
}

@test "private flake exposes the restore app from its pinned framework" {
  run_generator
  [ "$status" -eq 0 ]

  grep -qF 'apps."aarch64-darwin".restore = dotfiles.apps."aarch64-darwin".restore;' \
    "$PRIVATE/flake.nix"
  run grep -R 'scripts/bin/restore-profile' "$PRIVATE"
  [ "$status" -ne 0 ]
}

@test "host composition imports focused private modules normally" {
  run_generator
  [ "$status" -eq 0 ]

  grep -qF '../apps' "$PRIVATE/hosts/test-mac.nix"
  grep -qF '../macos' "$PRIVATE/hosts/test-mac.nix"
  grep -qF '../home' "$PRIVATE/hosts/test-mac.nix"
  grep -qF 'inputs.dotfiles.darwinModules.homeEnvironment' "$PRIVATE/hosts/test-mac.nix"
  grep -qF '../home.nix' "$PRIVATE/home/default.nix"

  run grep -R '\.local' "$PRIVATE"
  [ "$status" -ne 0 ]
}

@test "application choices have one focused source of truth" {
  run_generator
  [ "$status" -eq 0 ]

  grep -qF 'import ./homebrew-casks.nix' "$PRIVATE/apps/default.nix"
  grep -qF 'import ./nix-packages.nix' "$PRIVATE/apps/default.nix"
  grep -qF 'import ./mac-app-store.nix' "$PRIVATE/apps/default.nix"
  grep -qF 'dotfiles.homebrew.cleanup = "none"' "$PRIVATE/apps/default.nix"

  run find "$PRIVATE" -name apps.nix -print
  [ -z "$output" ]
}

@test "generated README teaches native Nix and direct recovery operations" {
  run_generator
  [ "$status" -eq 0 ]

  grep -qF 'nix flake update dotfiles' "$PRIVATE/README.md"
  grep -qF 'darwin-rebuild switch --flake .#test-mac' "$PRIVATE/README.md"
  grep -qF 'git diff -- flake.lock' "$PRIVATE/README.md"
  grep -qF 'dot adopt ~/.config/example' "$PRIVATE/README.md"
  grep -qF 'git clone <private-profile-repository> ~/dotfiles-private' "$PRIVATE/README.md"
  grep -qF './bootstrap' "$PRIVATE/README.md"
  grep -qF 'nix run .#restore' "$PRIVATE/README.md"
  grep -qF 'non-destructive preflight' "$PRIVATE/README.md"
  grep -qF './bootstrap --activate' "$PRIVATE/README.md"
  grep -qF './bootstrap --activate --yes' "$PRIVATE/README.md"
  grep -qF -- '--no-write-lock-file' "$PRIVATE/README.md"
}

@test "dot adopt writes modular profiles under home files" {
  run_generator
  [ "$status" -eq 0 ]

  git -C "$PRIVATE" init -q
  git -C "$PRIVATE" add .

  FAKE_HOME="$TMP/home"
  mkdir -p "$FAKE_HOME"
  printf 'contract\n' > "$FAKE_HOME/.adoptme"

  run env HOME="$FAKE_HOME" \
          DOTFILES_ROOT="$REPO_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
          "$DOT_ADOPT" adopt "$FAKE_HOME/.adoptme"
  [ "$status" -eq 0 ]

  [ -f "$PRIVATE/home/files/.adoptme" ]
  grep -qF '".adoptme".source = ./home/files/.adoptme;' "$PRIVATE/home.nix"
  grep -qF '../home.nix' "$PRIVATE/home/default.nix"

  run git -C "$PRIVATE" diff --cached --name-only
  [[ "$output" == *"home/files/.adoptme"* ]]
  [[ "$output" == *"home.nix"* ]]
}

@test "renderer refuses to overwrite an existing profile" {
  mkdir -p "$PRIVATE"
  printf 'keep me\n' > "$PRIVATE/existing.txt"

  run_generator
  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to overwrite"* ]]
  [ "$(cat "$PRIVATE/existing.txt")" = "keep me" ]
  [ ! -e "$PRIVATE/flake.nix" ]
  [ ! -e "$PRIVATE/bootstrap" ]
}
