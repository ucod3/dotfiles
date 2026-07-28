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
  cat > "$PROFILE/settings.nix" <<'EOF'
{
  ai.enable = true;
  casks = [ "firefox" "ghostty" ];
  nixPackages = [ "jq" ];
  masApps = {
    Notability = 360593530;
  };
}
EOF
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

@test "application preview records a private baseline without printing choices" {
  printf '{ casks = [ "zed" ]; nixPackages = [ "ripgrep" ]; }\n' \
    > "$PROFILE/apps.nix"
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm applications

  run_preview --applications
  assert_success
  assert_output_contains "Application migration evidence"
  assert_output_contains "settings.nix apps.nix"
  assert_output_contains "3 casks; 2 Nix packages; 1 App Store apps"
  assert_output_contains "legacy fingerprint"
  assert_output_contains "resolved equivalence"
  assert_output_contains "not comparable until targets exist"
  [[ "$output" != *"firefox"* ]]
  [[ "$output" != *"Notability"* ]]
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
}

@test "application preview proves exact modular equivalence" {
  mkdir -p "$PROFILE/apps"
  cat > "$PROFILE/apps/default.nix" <<'EOF'
{ pkgs, ... }: {
  homebrew.casks = import ./homebrew-casks.nix;
  environment.systemPackages = import ./nix-packages.nix { inherit pkgs; };
  homebrew.masApps = import ./mac-app-store.nix;
}
EOF
  cat > "$PROFILE/apps/homebrew-casks.nix" <<'EOF'
[
  "firefox"
  "ghostty"
]
EOF
  cat > "$PROFILE/apps/nix-packages.nix" <<'EOF'
{ pkgs }:
[
  pkgs.jq
]
EOF
  cat > "$PROFILE/apps/mac-app-store.nix" <<'EOF'
{
  Notability = 360593530;
}
EOF
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm modular-applications

  run_preview --applications
  assert_success
  assert_output_contains "modular declarations"
  assert_output_contains "2 casks; 1 Nix packages; 1 App Store apps"
  assert_output_contains "resolved equivalence"
  assert_output_contains "exact match"
  [ -z "$(git -C "$PROFILE" status --porcelain)" ]
}

@test "application preview reports mismatch and dirty migration blocker" {
  mkdir -p "$PROFILE/apps"
  printf '{ }\n' > "$PROFILE/apps/default.nix"
  printf '[\n  "firefox"\n]\n' > "$PROFILE/apps/homebrew-casks.nix"
  printf '{ pkgs }:\n[\n  pkgs.jq\n]\n' > "$PROFILE/apps/nix-packages.nix"
  printf '{\n}\n' > "$PROFILE/apps/mac-app-store.nix"
  git -C "$PROFILE" add -A
  git -C "$PROFILE" commit -qm mismatched-applications
  printf '# changed\n' >> "$PROFILE/README.md"

  run_preview --applications
  assert_success
  assert_output_contains "resolved equivalence"
  assert_output_contains "mismatch; do not continue"
  assert_output_contains "has uncommitted changes; migration must not start"
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
