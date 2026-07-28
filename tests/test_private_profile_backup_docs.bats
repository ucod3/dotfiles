#!/usr/bin/env bats

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  GUIDE="$REPO_ROOT/docs/PRIVATE_PROFILE_BACKUP.md"
  README="$REPO_ROOT/README.md"
  GETTING_STARTED="$REPO_ROOT/GETTING-STARTED.md"
  OPERATIONS="$REPO_ROOT/docs/OPERATIONS.md"
  PROFILE_README="$REPO_ROOT/templates/private-profile/README.md"
}

@test "public and generated guidance point to one backup contract" {
  grep -qF 'PRIVATE_PROFILE_BACKUP.md' "$README"
  grep -qF 'PRIVATE_PROFILE_BACKUP.md' "$GETTING_STARTED"
  grep -qF 'PRIVATE_PROFILE_BACKUP.md' "$OPERATIONS"
  grep -qF 'PRIVATE_PROFILE_BACKUP.md' "$PROFILE_README"
}

@test "backup guide is provider-neutral and requires private visibility" {
  grep -qF 'does not require a particular' "$GUIDE"
  grep -qF 'hosting provider' "$GUIDE"
  grep -qF 'mark it **private** before the first push' "$GUIDE"
  grep -qF 'Git itself cannot create an account or set a provider' "$GUIDE"

  run grep -E 'gh repo create|glab repo create' "$GUIDE"
  [ "$status" -ne 0 ]
}

@test "backup guide scans before publishing and explains backup limits" {
  grep -qF '## 2. Scan before publishing' "$GUIDE"
  grep -qF 'dot secrets "$PWD"' "$GUIDE"
  grep -qF 'does not remove it from older commits' "$GUIDE"
  grep -qF 'SSH private keys' "$GUIDE"
  grep -qF 'Time Machine' "$GUIDE"
}

@test "backup guide verifies the exact pushed commit" {
  grep -qF 'git push --set-upstream origin "$(git branch --show-current)"' "$GUIDE"
  grep -qF 'git log --oneline '\''@{upstream}..HEAD'\''' "$GUIDE"
  grep -qF 'git rev-parse '\''@{upstream}'\''' "$GUIDE"
  grep -qF 'prove that the provider marked the repository private' "$GUIDE"
  grep -qF 'repository private' "$GUIDE"
}

@test "restore rehearsal stays isolated and non-activating" {
  grep -qF 'mktemp -d -t dotfiles-restore-rehearsal' "$GUIDE"
  grep -qF -- '--profile-dir "$rehearsal_root/dotfiles-private"' "$GUIDE"
  grep -qF 'Activation: not performed' "$GUIDE"
  grep -qF 'Do not add `--activate`' "$GUIDE"
  grep -qF 'status --short' "$GUIDE"
}
