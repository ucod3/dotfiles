#!/usr/bin/env bats

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  MIGRATE="$REPO_ROOT/scripts/bin/migrate-profile"
  DOT="$REPO_ROOT/scripts/bin/dot"
  TMP="$(mktemp -d -t migration_preview.XXXXXX)"
  PROFILE="$TMP/dotfiles-private"
  FRAMEWORK="$TMP/dotfiles"
  mkdir -p "$PROFILE/hosts" "$PROFILE/home" "$FRAMEWORK"

  git -C "$PROFILE" init -q
  git -C "$PROFILE" config user.name Test
  git -C "$PROFILE" config user.email test@example.com
  git -C "$PROFILE" remote add origin "$TMP/private-remote.git"

  cat > "$PROFILE/flake.nix" <<'EOF'
{
  outputs = { ... }: {
    darwinConfigurations.example = { };
  };
}
EOF
  printf '{}\n' > "$PROFILE/flake.lock"
  printf '#!/bin/sh\n' > "$PROFILE/bootstrap"
  printf '# Profile\n' > "$PROFILE/README.md"
  printf '{ ai.enable = true; }\n' > "$PROFILE/settings.nix"
  printf '{ name = "Private"; }\n' > "$PROFILE/identity.nix"
  printf 'managed\n' > "$PROFILE/home/example"
  cat > "$PROFILE/home.nix" <<'EOF'
{ ... }: {
  home.file.".example".source = ./home/example;
}
EOF
  cat > "$PROFILE/hosts/example.nix" <<'EOF'
{ ... }: {
  home-manager.users.example.imports = [ ../home.nix ];
}
EOF
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm init

  ln -s "$PROFILE" "$FRAMEWORK/.local"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

run_preview() {
  run env \
    DOTFILES_ROOT="$FRAMEWORK" \
    DOTFILES_PRIVATE_FLAKE="$PROFILE" \
    bash "$MIGRATE" "$@"
}

@test "legacy preview reports active sources by evidence without changing them" {
  before="$(git -C "$PROFILE" rev-parse HEAD)"

  run_preview --preview
  assert_success
  assert_output_contains "Layout:         legacy"
  assert_output_contains "active through the .local compatibility loader"
  assert_output_contains "home.nix"
  assert_output_contains "imported by a committed host module"
  assert_output_contains "home/"
  assert_output_contains "referenced by home.nix adopted-file mappings"
  assert_output_contains "apps"
  assert_output_contains "missing"
  assert_output_contains "No changes were made."
  [ "$before" = "$(git -C "$PROFILE" rev-parse HEAD)" ]
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
}

@test "modular preview recognizes focused targets without inventing legacy use" {
  mkdir -p "$PROFILE/apps" "$PROFILE/macos"
  printf '{ imports = [ ../home.nix ]; }\n' > "$PROFILE/home/default.nix"
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm modular
  rm "$FRAMEWORK/.local"

  run_preview
  assert_success
  assert_output_contains "Layout:         modular"
  assert_output_contains "no active .local evidence"
  assert_output_contains "apps"
  assert_output_contains "present"
  assert_output_contains "macos"
  assert_output_contains "present"
  assert_output_contains "home/default.nix"
}

@test "preview refuses every write-shaped option" {
  run_preview --apply
  assert_failure
  assert_output_contains "only read-only preview is implemented"
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
}

@test "dot dispatches the migration preview" {
  run env \
    DOTFILES_ROOT="$REPO_ROOT" \
    DOTFILES_PRIVATE_FLAKE="$PROFILE" \
    DOTFILES_LOCAL="$PROFILE" \
    "$DOT" migrate --preview
  assert_success
  assert_output_contains "Private-profile migration preview"
}
