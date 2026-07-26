#!/usr/bin/env bats
#
# Regression tests for the adoptability remediation (ADR-010, ADR-011).
#
# These pin the properties that make this framework forkable rather than
# merely readable: an adopter owns their own pin, a second Mac needs no manual
# flake surgery, `dot apps list` tells the truth about what is installed, and
# the shell a cold fork gets does not redefine anyone's commands.
#
# Where a behaviour needs Nix or macOS to observe directly, the test pins the
# script text that produces it — the same approach test_rebuild.bats takes.
#

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  SPH="$REPO_ROOT/scripts/bin/setup-private-host"
  APPS="$REPO_ROOT/scripts/bin/apps"
  PROMOTE="$REPO_ROOT/scripts/bin/promote"

  TMP="$(mktemp -d -t dotfiles_adopt.XXXXXX)"

  # A stand-in for a fork of this framework: a git repo whose origin is a
  # GitHub URL, carrying the real lib/ and scripts/ so the scripts under test
  # can source their dependencies.
  FAKE_ROOT="$TMP/root"
  mkdir -p "$FAKE_ROOT"
  git -C "$FAKE_ROOT" init -q
  ln -s "$(cd "$REPO_ROOT" && pwd -P)/lib" "$FAKE_ROOT/lib"
  ln -s "$(cd "$REPO_ROOT" && pwd -P)/scripts" "$FAKE_ROOT/scripts"
  touch "$FAKE_ROOT/flake.nix"

  # A stub `nix`, first on PATH for the sandbox only.
  #
  # setup-private-host ends with `nix flake lock`. These tests pin the FILES it
  # writes, and a real lock would try to fetch `github:bob/dotfiles` — a
  # repository that does not exist — so the suite would depend on the network
  # and on whether nix happens to be installed. Neither is something these
  # assertions are about.
  STUB_BIN="$TMP/bin"
  mkdir -p "$STUB_BIN"
  printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/nix"
  chmod +x "$STUB_BIN/nix"
}

teardown() {
  [[ -n "${TMP:-}" ]] && rm -rf "$TMP"
}

set_origin() {
  git -C "$FAKE_ROOT" remote remove origin 2>/dev/null || true
  git -C "$FAKE_ROOT" remote add origin "$1"
}

# Generate a private flake against the sandbox, with the stub `nix` on PATH.
# stdin is closed so the upstream-fork prompt takes its non-interactive branch.
run_sph() {
  run env HOME="$TMP" \
          PATH="$STUB_BIN:$PATH" \
          DOTFILES_ROOT="$FAKE_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
          "$SPH" "$@" < /dev/null
}

# ── Fork ownership (ADR-010) ─────────────────────────────────────────────────

@test "an explicit --fork is what gets pinned" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:ucod3/dotfiles.git"
  run_sph --host mac --user alice --fork bob/my-dots
  grep -q 'dotfiles.url = "github:bob/my-dots"' "$PRIVATE/flake.nix"
}

@test "--fork accepts a full clone URL, not just OWNER/REPO" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:ucod3/dotfiles.git"
  run_sph --host mac --user alice --fork https://github.com/bob/my-dots.git
  grep -q 'dotfiles.url = "github:bob/my-dots"' "$PRIVATE/flake.nix"
}

@test "DOTFILES_FORK is honoured like --fork" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:ucod3/dotfiles.git"
  run env HOME="$TMP" PATH="$STUB_BIN:$PATH" DOTFILES_ROOT="$FAKE_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$PRIVATE" DOTFILES_FORK=carol/dots \
          "$SPH" --host mac --user alice < /dev/null
  grep -q 'dotfiles.url = "github:carol/dots"' "$PRIVATE/flake.nix"
}

@test "pinning to the upstream author's remote warns loudly" {
  # The whole point of the guard: cloning upstream and running bootstrap must
  # not silently produce a machine that rebuilds from someone else's repo.
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:ucod3/dotfiles.git"
  run_sph --host mac --user alice
  [[ "$output" == *"upstream framework"* ]]
  [[ "$output" == *"--fork"* ]]
}

@test "a fork's own origin is pinned without any warning" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:someone-else/dotfiles.git"
  run_sph --host mac --user alice
  grep -q 'dotfiles.url = "github:someone-else/dotfiles"' "$PRIVATE/flake.nix"
  [[ "$output" != *"upstream framework"* ]]
}

# ── Multi-Mac deployment (ADR-010) ───────────────────────────────────────────

@test "the generated flake enumerates hosts/ instead of naming one host" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice

  grep -q 'builtins.readDir ./hosts' "$PRIVATE/flake.nix"
  # A hardcoded darwinConfigurations."<host>" is exactly what forced a manual
  # edit on the second machine.
  run grep -q 'darwinConfigurations."mac-one"' "$PRIVATE/flake.nix"
  [ "$status" -ne 0 ]
}

@test "a second Mac is added without touching flake.nix" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice
  before="$(cat "$PRIVATE/flake.nix")"

  run_sph --host mac-two --user alice
  [ "$status" -eq 0 ]

  [ -f "$PRIVATE/hosts/mac-two.nix" ]
  [ "$before" = "$(cat "$PRIVATE/flake.nix")" ]
  # No "paste this block into your flake" instructions any more.
  [[ "$output" != *"darwinConfigurations."* ]]
}

@test "a newly added host file is staged (R2)" {
  # git+file: evaluation excludes untracked files, so an unstaged host file is
  # invisible to the very rebuild that is supposed to consume it.
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice
  run_sph --host mac-two --user alice

  run git -C "$PRIVATE" diff --cached --name-only
  [[ "$output" == *"hosts/mac-two.nix"* ]]
}

@test "re-running for a known host is a no-op" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice

  run_sph --host mac-one --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"already defines"* ]]
}

# ── Adoption wiring (ADR-010) ────────────────────────────────────────────────

@test "the generated host file imports home.nix as an extensible list" {
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice

  # `users.<user> = import ...` took a single module, so every `dot adopt`
  # required hand-editing the host file before it would deploy.
  grep -q 'users.${user}.imports = \[' "$PRIVATE/hosts/mac-one.nix"
  grep -q '\.\./home\.nix' "$PRIVATE/hosts/mac-one.nix"
}

@test "home.nix exists with the adoption sentinel from the start" {
  # The host file imports it unconditionally, and importing a missing path is
  # an evaluation error rather than a no-op.
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice

  [ -f "$PRIVATE/home.nix" ]
  grep -q 'dot-adopt:entries' "$PRIVATE/home.nix"
}

@test "dot adopt appends into the flake-generated home.nix" {
  # End to end: the file setup-private-host wrote must be the one dot-adopt
  # extends — a drifted sentinel would make adoption create a second file that
  # nothing imports.
  PRIVATE="$TMP/priv"
  set_origin "git@github.com:bob/dotfiles.git"
  run_sph --host mac-one --user alice

  FAKE_HOME="$TMP/home"
  mkdir -p "$FAKE_HOME"
  printf 'contract\n' > "$FAKE_HOME/.adoptme"
  git -C "$PRIVATE" config user.email test@example.com
  git -C "$PRIVATE" config user.name Test

  run env HOME="$FAKE_HOME" DOTFILES_ROOT="$REPO_ROOT" \
          DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
          "$REPO_ROOT/scripts/bin/dot-adopt" adopt "$FAKE_HOME/.adoptme"
  [ "$status" -eq 0 ]

  grep -qF '".adoptme".source = ./home/.adoptme;' "$PRIVATE/home.nix"
  # Exactly one home.nix, still carrying its sentinel.
  grep -q 'dot-adopt:entries' "$PRIVATE/home.nix"
}

# ── Path variable unification ────────────────────────────────────────────────

@test "DOTFILES_PRIVATE_FLAKE is the canonical private-flake variable" {
  run bash -c "unset DOTFILES_PRIVATE DOTFILES_PRIVATE_FLAKE
    source '$REPO_ROOT/lib/paths.sh'
    DOTFILES_PRIVATE_FLAKE=/canonical private_flake_root"
  [ "$status" -eq 0 ]
  [ "$output" = "/canonical" ]
}

@test "the legacy DOTFILES_PRIVATE spelling still resolves" {
  # dot-adopt read this name while every other script read
  # DOTFILES_PRIVATE_FLAKE — two names for one directory. Honour it, warn once.
  run bash -c "unset DOTFILES_PRIVATE DOTFILES_PRIVATE_FLAKE
    source '$REPO_ROOT/lib/paths.sh'
    DOTFILES_PRIVATE=/legacy private_flake_root 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$output" = "/legacy" ]
}

@test "dotfiles_root finds the repo from the script's own location" {
  # A clone outside ~/dotfiles must work: every script used to hardcode
  # \$HOME/dotfiles as its fallback.
  run bash -c "unset DOTFILES_ROOT
    source '$REPO_ROOT/lib/paths.sh'
    dotfiles_root"
  [ "$status" -eq 0 ]
  [ "$output" = "$(cd "$REPO_ROOT" && pwd -P)" ]
}

@test "an explicit DOTFILES_ROOT always wins" {
  run bash -c "DOTFILES_ROOT=/explicit
    source '$REPO_ROOT/lib/paths.sh'
    dotfiles_root"
  [ "$status" -eq 0 ]
  [ "$output" = "/explicit" ]
}

# ── Honest app reporting ─────────────────────────────────────────────────────

@test "apps list reports casks declared in .local/" {
  # The de-opinionated refactor moved cask declarations into .local/, but the
  # parser still only read hosts/default.nix — so `apps list` printed zero
  # casks on a machine with a dozen installed.
  LOCAL="$TMP/local"
  mkdir -p "$LOCAL"
  printf '{\n  casks = [\n    "ghostty"\n  ];\n  nixPackages = [ ];\n}\n' > "$LOCAL/apps.nix"

  run env DOTFILES_ROOT="$REPO_ROOT" DOTFILES_LOCAL="$LOCAL" "$APPS" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ghostty"* ]]
}

@test "apps list reads single-line lists written by install.sh" {
  # install.sh writes `casks = [ "firefox" "google-chrome" ];` on one line;
  # a line-oriented parser reads that as an empty list.
  LOCAL="$TMP/local"
  mkdir -p "$LOCAL/browsers"
  printf '{\n  casks = [ "firefox" "google-chrome" ];\n  nixPackages = [ "brave" ];\n}\n' \
    > "$LOCAL/browsers/choices.nix"

  run env DOTFILES_ROOT="$REPO_ROOT" DOTFILES_LOCAL="$LOCAL" "$APPS" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"firefox"* ]]
  [[ "$output" == *"google-chrome"* ]]
}

@test "a nixPackage is not reported as a cask" {
  # The same line-oriented parser ran past the end of one list into the next,
  # filing Nix packages under Homebrew casks.
  LOCAL="$TMP/local"
  mkdir -p "$LOCAL/browsers"
  printf '{\n  casks = [ "firefox" ];\n  nixPackages = [ "brave" ];\n}\n' \
    > "$LOCAL/browsers/choices.nix"

  run env DOTFILES_ROOT="$REPO_ROOT" DOTFILES_LOCAL="$LOCAL" "$APPS" list
  [ "$status" -eq 0 ]
  casks_section="${output%%Nix packages*}"
  [[ "$casks_section" != *"brave"* ]]
}

@test "apps list reports the framework sets' mkOption defaults" {
  # App sets declare their lists as option defaults, not literal attributes.
  LOCAL="$TMP/local"
  mkdir -p "$LOCAL"
  printf '{ }\n' > "$LOCAL/settings.nix"

  run env DOTFILES_ROOT="$REPO_ROOT" DOTFILES_LOCAL="$LOCAL" "$APPS" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"arc"* ]]        # nix/modules/apps/browsers.nix
  [[ "$output" == *"raycast"* ]]    # nix/modules/apps/productivity.nix
}

# ── validate reliability ─────────────────────────────────────────────────────

@test "a failing bats suite is an error, not a warning" {
  # validate used to `warn` here and still exit 0, so the fail-closed
  # pre-commit hook happily committed against a red suite.
  run grep -A4 'if bats tests/' "$REPO_ROOT/scripts/bin/validate"
  [ "$status" -eq 0 ]
  [[ "$output" == *'fail "bats tests failed'* ]]
  [[ "$output" != *'warn "Some bats tests failed'* ]]
}

@test "validate does not discard the bats output it points at" {
  run grep -q 'bats tests/ 2>/dev/null' "$REPO_ROOT/scripts/bin/validate"
  [ "$status" -ne 0 ]
}

# ── promote ──────────────────────────────────────────────────────────────────

@test "promote refuses a dirty working tree" {
  # Promoting a dirty tree publishes a revision that is not what you are
  # looking at.
  git -C "$FAKE_ROOT" config user.email test@example.com
  git -C "$FAKE_ROOT" config user.name Test
  git -C "$FAKE_ROOT" add -A
  git -C "$FAKE_ROOT" commit -qm init
  printf 'dirty\n' > "$FAKE_ROOT/dirty.txt"

  branch="$(git -C "$FAKE_ROOT" rev-parse --abbrev-ref HEAD)"
  run env DOTFILES_ROOT="$FAKE_ROOT" DOTFILES_PRIVATE_FLAKE="$TMP/priv" \
          "$PROMOTE" --dry-run --branch "$branch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not clean"* ]]
}

@test "promote refuses when no private flake pins this repo" {
  git -C "$FAKE_ROOT" config user.email test@example.com
  git -C "$FAKE_ROOT" config user.name Test
  git -C "$FAKE_ROOT" add -A
  git -C "$FAKE_ROOT" commit -qm init

  branch="$(git -C "$FAKE_ROOT" rev-parse --abbrev-ref HEAD)"
  run env DOTFILES_ROOT="$FAKE_ROOT" DOTFILES_PRIVATE_FLAKE="$TMP/nonexistent" \
          "$PROMOTE" --dry-run --branch "$branch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No private flake"* ]]
}

@test "promote refuses to promote a branch you are not on" {
  run env DOTFILES_ROOT="$FAKE_ROOT" "$PROMOTE" --dry-run --branch not-my-branch
  [ "$status" -eq 1 ]
  [[ "$output" == *"asked to promote"* ]]
}

@test "promote --dry-run changes nothing" {
  git -C "$FAKE_ROOT" config user.email test@example.com
  git -C "$FAKE_ROOT" config user.name Test
  git -C "$FAKE_ROOT" add -A
  git -C "$FAKE_ROOT" commit -qm init

  PRIVATE="$TMP/priv"
  mkdir -p "$PRIVATE"
  git -C "$PRIVATE" init -q
  printf '{ }\n' > "$PRIVATE/flake.nix"
  printf 'original\n' > "$PRIVATE/flake.lock"

  branch="$(git -C "$FAKE_ROOT" rev-parse --abbrev-ref HEAD)"
  run env DOTFILES_ROOT="$FAKE_ROOT" DOTFILES_PRIVATE_FLAKE="$PRIVATE" \
          "$PROMOTE" --dry-run --skip-validate --branch "$branch"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  grep -q original "$PRIVATE/flake.lock"
  run git -C "$PRIVATE" log --oneline
  [ "$status" -ne 0 ]
}

@test "promote pushes before moving the pin" {
  # The pin can only name a revision the remote already has.
  push_line="$(grep -n 'git -C "\$DOTFILES_ROOT" push -u origin' "$PROMOTE" | head -1 | cut -d: -f1)"
  pin_line="$(grep -n 'nix flake update dotfiles' "$PROMOTE" | tail -1 | cut -d: -f1)"
  [ -n "$push_line" ]
  [ -n "$pin_line" ]
  [ "$push_line" -lt "$pin_line" ]
}

@test "dot dispatches promote" {
  run grep -q 'exec "$BIN/promote"' "$REPO_ROOT/scripts/bin/dot"
  [ "$status" -eq 0 ]
}

# ── A neutral shell on a cold fork (ADR-011) ─────────────────────────────────

@test "the default module set excludes everything opinionated" {
  run grep -F 'DOTFILES_ZSH_MODULES:-' "$REPO_ROOT/config/zsh/custom.zsh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"workshop"* ]]        # writes .workshop.env into your repos
  [[ "$output" != *"aliases-personal"* ]] # redefines npm, ls, help
  [[ "$output" != *"npm-compat"* ]]
}

@test "a cold-fork shell defines no npm, ls or epic-detect override" {
  command -v zsh >/dev/null || skip "zsh not installed"
  run env -u DOTFILES_ZSH_MODULES HOME="$TMP" DOTFILES_ROOT="$REPO_ROOT" zsh -c "
    source '$REPO_ROOT/config/zsh/.zshenv'
    source '$REPO_ROOT/config/zsh/custom.zsh'
    alias npm 2>/dev/null && echo LEAK_NPM
    alias ll  2>/dev/null && echo LEAK_LL
    type epic-detect >/dev/null 2>&1 && echo LEAK_EPIC
    alias dot >/dev/null 2>&1 || echo MISSING_DOT
    true
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"LEAK_NPM"* ]]
  [[ "$output" != *"LEAK_LL"* ]]
  [[ "$output" != *"LEAK_EPIC"* ]]
  [[ "$output" != *"MISSING_DOT"* ]]
}

@test "enabling the modules brings the opinionated layer back" {
  command -v zsh >/dev/null || skip "zsh not installed"
  run env HOME="$TMP" DOTFILES_ROOT="$REPO_ROOT" \
      DOTFILES_ZSH_MODULES="init node utils npm-compat aliases aliases-personal workshop exports" \
      zsh -c "
    source '$REPO_ROOT/config/zsh/.zshenv'
    source '$REPO_ROOT/config/zsh/custom.zsh'
    alias ll >/dev/null 2>&1 && echo HAS_LL
    type epic-detect >/dev/null 2>&1 && echo HAS_EPIC
    true
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"HAS_LL"* ]]
  [[ "$output" == *"HAS_EPIC"* ]]
}

@test "no shell start writes npm shims into ~/.local/bin" {
  command -v zsh >/dev/null || skip "zsh not installed"
  shimhome="$TMP/shimhome"
  mkdir -p "$shimhome"
  run env HOME="$shimhome" DOTFILES_ROOT="$REPO_ROOT" zsh -c "
    source '$REPO_ROOT/config/zsh/.zshenv'
    source '$REPO_ROOT/config/zsh/custom.zsh'
    true
  "
  [ "$status" -eq 0 ]
  # An imperative write no rebuild or rollback could ever retract, breaking
  # `npm` for every process on the machine.
  [ ! -e "$shimhome/.local/bin/npm" ]
  [ ! -e "$shimhome/.local/bin/npx" ]
  [ ! -e "$shimhome/.local/bin/yarn" ]
}

@test "the unmanaged escape hatches are sourced last" {
  command -v zsh >/dev/null || skip "zsh not installed"
  hatchhome="$TMP/hatchhome"
  mkdir -p "$hatchhome"
  printf 'export FROM_ZSHRC_LOCAL=yes\n' > "$hatchhome/.zshrc.local"

  run env HOME="$hatchhome" DOTFILES_ROOT="$REPO_ROOT" zsh -c "
    source '$REPO_ROOT/config/zsh/.zshenv'
    source '$REPO_ROOT/config/zsh/custom.zsh'
    echo \"HATCH=\${FROM_ZSHRC_LOCAL:-no}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"HATCH=yes"* ]]
}

@test "the escape-hatch template ships and the real file is ignored" {
  [ -f "$REPO_ROOT/config/zsh/custom.local.zsh.example" ]
  run grep -q '^config/zsh/custom\.local\.zsh$' "$REPO_ROOT/.gitignore"
  [ "$status" -eq 0 ]
  run grep -q '^\.zshrc\.local$' "$REPO_ROOT/.gitignore"
  [ "$status" -eq 0 ]
}

# ── Neutral git core (ADR-011) ───────────────────────────────────────────────

@test "the base git config imposes no workflow" {
  cfg="$REPO_ROOT/config/git/config"
  for key in "editor = nvim" "rebase = true" "autoSetupRebase" "tool = nvimdiff"; do
    run grep -q "$key" "$cfg"
    [ "$status" -ne 0 ]
  done
  # The neutral half stays.
  run grep -q 'defaultBranch = main' "$cfg"
  [ "$status" -eq 0 ]
}

@test "the opinionated git profile exists and is included by path" {
  # git ignores a missing include, so not writing the file IS the off switch.
  [ -f "$REPO_ROOT/config/git/config-opinionated" ]
  run grep -q 'path = config-opinionated' "$REPO_ROOT/config/git/config"
  [ "$status" -eq 0 ]
  run grep -q 'rebase = true' "$REPO_ROOT/config/git/config-opinionated"
  [ "$status" -eq 0 ]
}

# ── macOS editor integration ─────────────────────────────────────────────────

@test "editor settings target the macOS path, not XDG" {
  # VS Code and its forks read ~/Library/Application Support on macOS and never
  # look at $XDG_CONFIG_HOME, so the old xdg.configFile mapping did nothing.
  home_nix="$REPO_ROOT/nix/home/home.nix"
  run grep -q '"Library/Application Support/${cfg.vscode.configDir}/User/settings.json"' "$home_nix"
  [ "$status" -eq 0 ]
  run grep -q '"Library/Application Support/${cfg.cursor.configDir}/User/settings.json"' "$home_nix"
  [ "$status" -eq 0 ]
  run grep -q '"${cfg.vscode.configDir}/User/settings.json".source' "$home_nix"
  [ "$status" -ne 0 ]
}

# ── Installer ────────────────────────────────────────────────────────────────

@test "the installer can be pointed at a fork" {
  run grep -q 'DOTFILES_REPO_URL' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  run grep -q 'resolve_repo_url' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
}

@test "every installer menu is multi-select" {
  # Terminal and window manager took a single answer and silently discarded
  # the rest of the selection.
  run grep -q 'select_menu "terminal(s)"' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  run grep -qE 'select_menu "[^"]+" (yes|no) ' "$REPO_ROOT/install.sh"
  [ "$status" -ne 0 ]
}

@test "the installer offers Warp and accepts free-text casks" {
  run grep -q 'warp)' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  run grep -q 'prompt_extra_casks' "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
}

# ── Licensing ────────────────────────────────────────────────────────────────

@test "the MIT license the README claims actually exists" {
  [ -f "$REPO_ROOT/LICENSE" ]
  run grep -q 'MIT License' "$REPO_ROOT/LICENSE"
  [ "$status" -eq 0 ]
}
