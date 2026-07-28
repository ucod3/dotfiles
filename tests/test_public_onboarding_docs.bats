#!/usr/bin/env bats

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  README="$REPO_ROOT/README.md"
  GETTING_STARTED="$REPO_ROOT/GETTING-STARTED.md"
  SETUP="$REPO_ROOT/setup.sh"
}

@test "public onboarding uses setup.sh instead of the legacy installer" {
  grep -qF 'main/setup.sh' "$README"
  grep -qF 'main/setup.sh' "$GETTING_STARTED"

  run grep -F 'main/install.sh' "$README" "$GETTING_STARTED"
  [ "$status" -ne 0 ]

  run grep -E -i 'fork (this|the) (repo|repository) first' \
    "$README" "$GETTING_STARTED"
  [ "$status" -ne 0 ]
}

@test "public onboarding teaches both profile journeys and explicit activation" {
  run bash "$SETUP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--new"* ]]
  [[ "$output" == *"--restore REPOSITORY"* ]]
  [[ "$output" == *"--activate"* ]]

  grep -qF -- '--new' "$README"
  grep -qF -- '--restore' "$README"
  grep -qF 'non-destructive preflight' "$README"
  grep -qF -- '--activate' "$GETTING_STARTED"
}

@test "new-profile documentation points to focused private sources of truth" {
  grep -qF 'homebrew-casks.nix' "$README"
  grep -qF 'apps/nix-packages.nix' "$GETTING_STARTED"
  grep -qF 'apps/mac-app-store.nix' "$GETTING_STARTED"
  grep -qF 'macos/default.nix' "$GETTING_STARTED"
  grep -qF 'home/default.nix' "$GETTING_STARTED"
  grep -qF 'hosts/<hostname>.nix' "$GETTING_STARTED"
}

@test "legacy local settings are labeled as compatibility rather than onboarding" {
  run grep -F '.local/settings.nix' "$README"
  [ "$status" -ne 0 ]

  grep -qF 'legacy compatibility path' "$GETTING_STARTED"
}
