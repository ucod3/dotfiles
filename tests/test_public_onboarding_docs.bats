#!/usr/bin/env bats

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  README="$REPO_ROOT/README.md"
  GETTING_STARTED="$REPO_ROOT/GETTING-STARTED.md"
  ARCHITECTURE="$REPO_ROOT/docs/ARCHITECTURE.md"
  PRIVATE_HOST="$REPO_ROOT/docs/PRIVATE_HOST_SETUP.md"
  OPERATIONS="$REPO_ROOT/docs/OPERATIONS.md"
  ROADMAP="$REPO_ROOT/docs/ROADMAP.md"
  DEVIN_SETUP="$REPO_ROOT/docs/ai/devin.md"
  TESTING="$REPO_ROOT/docs/TESTING.md"
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

@test "architecture documents upstream profiles and declarative Homebrew ownership" {
  grep -qF 'inputs.dotfiles.url = "github:ucod3/dotfiles";' "$ARCHITECTURE"
  grep -qF '`nix-homebrew` installs or adopts the Homebrew installation' \
    "$ARCHITECTURE"
  grep -qF 'Home Manager does not install or own Homebrew' "$ARCHITECTURE"
  grep -qF 'Legacy `.local/` compatibility' "$ARCHITECTURE"
}

@test "host setup uses the current profile journey without requiring a fork" {
  grep -qF 'main/setup.sh' "$PRIVATE_HOST"
  grep -qF 'inputs.dotfiles.url = "github:ucod3/dotfiles";' "$PRIVATE_HOST"
  grep -qF 'does not otherwise require a fork' "$PRIVATE_HOST"
  grep -qF 'restore command currently stops' "$PRIVATE_HOST"

  run grep -E -i '(must|required to) (use |create )?(your |a )?fork' \
    "$PRIVATE_HOST"
  [ "$status" -ne 0 ]
}

@test "testing guidance treats setup.sh as the public entry point" {
  grep -qF '## Testing public setup' "$TESTING"
  grep -qF '`setup.sh` supports command-double tests' "$TESTING"
  grep -qF '`install.sh` remains a legacy compatibility entry point' "$TESTING"
}

@test "ordinary updates move the private framework pin" {
  grep -qF '## Update the pinned framework' "$OPERATIONS"
  grep -qF 'cd ~/dotfiles-private' "$OPERATIONS"
  grep -qF 'nix flake update dotfiles' "$OPERATIONS"
  grep -qF 'Restore never performs this update automatically' "$OPERATIONS"
}

@test "framework maintainer commands are not presented as ordinary profile work" {
  grep -qF '`dot update` and `dot promote` currently operate on the public framework' \
    "$OPERATIONS"
  grep -qF 'ordinary upstream consumer should not use `dot promote`' "$OPERATIONS"

  run grep -F 'dot update' "$README"
  [ "$status" -ne 0 ]

  run grep -F 'What matters is `.local/`' "$OPERATIONS"
  [ "$status" -ne 0 ]
}

@test "AI editor link documentation distinguishes legacy and modular behavior" {
  grep -qF '### Current legacy-profile behavior' "$DEVIN_SETUP"
  grep -qF 'does **not** enable these Home Manager' "$DEVIN_SETUP"
  grep -qF 'links yet, because their remaining gate' "$DEVIN_SETUP"
  grep -qF 'AI editor links move from the legacy `.local` flag' "$ROADMAP"
  grep -qF 'Home Manager option while retaining the legacy flag' "$ROADMAP"
}
