#!/usr/bin/env bats
#
# Regression tests for the cold-clone / first-run path.
#
# These pin behaviours that a fresh Mac depends on and that regressed silently
# before, because they only misbehave on a machine that lacks the tooling this
# repo installs. See ADR-007 and docs/DECISIONS.md.
#

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  # A PATH with neither brew nor nix, to stand in for a machine before the
  # first build has run.
  BARE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
}

@test "check-brew-manual-installers exits 0 when brew is absent" {
  # It is a post-rebuild advisory. Exiting non-zero here made a SUCCESSFUL
  # darwin-rebuild switch report overall failure, because rebuild runs under
  # `set -euo pipefail`.
  run env PATH="$BARE_PATH" "$REPO_ROOT/scripts/bin/check-brew-manual-installers"
  [ "$status" -eq 0 ]
}

@test "lib/nix.sh enables flakes in NIX_CONFIG" {
  # The stock Nix installer does not enable flakes, and hosts/default.nix only
  # applies them AFTER a successful build — which is itself a flake command.
  run bash -c "unset NIX_CONFIG; source '$REPO_ROOT/lib/nix.sh'; echo \"\$NIX_CONFIG\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"nix-command"* ]]
  [[ "$output" == *"flakes"* ]]
}

@test "lib/nix.sh does not clobber an existing NIX_CONFIG" {
  run bash -c "export NIX_CONFIG='warn-dirty = false'; source '$REPO_ROOT/lib/nix.sh'; echo \"\$NIX_CONFIG\""
  [ "$status" -eq 0 ]
  [[ "$output" == *"warn-dirty = false"* ]]
  [[ "$output" == *"experimental-features"* ]]
}

@test "nix_system derives the host architecture" {
  run bash -c "source '$REPO_ROOT/lib/nix.sh'; nix_system"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-darwin" ]]
}

@test "rebuild has a darwin-rebuild fallback for the first build" {
  # darwin-rebuild does not exist until nix-darwin has been activated once, and
  # the first activation is what installs it. Without a `nix run` fallback the
  # very first rebuild died with "command not found" and no explanation.
  run grep -q "nix-darwin/master#darwin-rebuild" "$REPO_ROOT/scripts/bin/rebuild"
  [ "$status" -eq 0 ]
}

@test "the pre-commit hook can obtain gitleaks without Homebrew" {
  # gitleaks ships via nix-darwin, but install-hooks runs on a fresh clone
  # before that build. The hook must still be able to scan.
  run grep -q "nixpkgs#gitleaks" "$REPO_ROOT/scripts/bin/install-hooks"
  [ "$status" -eq 0 ]
}

@test "rebuild treats a bare directory as no settings layer" {
  # A directory with no recognized settings file must not count as a settings
  # layer: ~/dotfiles-private is created with only flake.nix/hosts/, and
  # treating it as one enabled destructive Homebrew pruning (ADR-007).
  bare="$(mktemp -d)"
  run bash -c "
    source '$REPO_ROOT/lib/log.sh'
    has_settings_layer() {
      local d=\"\$1\"
      [[ -e \"\$d/settings.nix\" || -e \"\$d/identity.nix\" || -e \"\$d/apps.nix\" \
         || -e \"\$d/browsers/choices.nix\" || -e \"\$d/editors/choices.nix\" ]]
    }
    has_settings_layer '$bare'
  "
  rm -rf "$bare"
  [ "$status" -ne 0 ]
}

@test "a directory with settings.nix is a settings layer" {
  layer="$(mktemp -d)"
  echo '{ }' > "$layer/settings.nix"
  run bash -c "
    has_settings_layer() {
      local d=\"\$1\"
      [[ -e \"\$d/settings.nix\" || -e \"\$d/identity.nix\" || -e \"\$d/apps.nix\" \
         || -e \"\$d/browsers/choices.nix\" || -e \"\$d/editors/choices.nix\" ]]
    }
    has_settings_layer '$layer'
  "
  rm -rf "$layer"
  [ "$status" -eq 0 ]
}
