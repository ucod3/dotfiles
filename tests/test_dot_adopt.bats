#!/usr/bin/env bats
#
# Guard tests for `dot adopt` / `dot scan-unmapped`.
#
# Adoption MOVES real files out of $HOME, so every one of these guards is the
# difference between a refusal and unrecoverable damage to a live home
# directory. They run against a sandbox $HOME and a throwaway private repo —
# never the operator's actual one.
#
# The guard that matters most is the last group: Home Manager writes per-file
# symlinks into real directories, so adopting a directory it already owns files
# in would move /nix/store links into the private repo and leave two owners
# fighting over the same paths.
#

setup() {
  load 'bats_helper'
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  ADOPT="$REPO_ROOT/scripts/bin/dot-adopt"

  FAKE_HOME="$(mktemp -d -t dot_adopt_home.XXXXXX)"
  FAKE_PRIVATE="$(mktemp -d -t dot_adopt_priv.XXXXXX)"
  # Somewhere to put a stand-in `origin` that is not $HOME — a bare repo under
  # the sandbox home would itself be scanned as an adoption candidate.
  FAKE_SCRATCH="$(mktemp -d -t dot_adopt_scratch.XXXXXX)"

  # The script requires a real git repo (R2 — it stages what it moves).
  git -C "$FAKE_PRIVATE" init -q
  git -C "$FAKE_PRIVATE" config user.email "test@example.com"
  git -C "$FAKE_PRIVATE" config user.name "Test"

  mkdir -p "$FAKE_HOME/.config"
  printf 'contract\n' > "$FAKE_HOME/.plainfile"
}

teardown() {
  [[ -n "${FAKE_HOME:-}" ]] && rm -rf "$FAKE_HOME"
  [[ -n "${FAKE_PRIVATE:-}" ]] && rm -rf "$FAKE_PRIVATE"
  [[ -n "${FAKE_SCRATCH:-}" ]] && rm -rf "$FAKE_SCRATCH"
}

# Give the sandbox private repo a local remote and a first published commit,
# so tests can then diverge from it deliberately.
publish_private_sandbox() {
  git init -q --bare "$FAKE_SCRATCH/origin.git"
  printf 'seed\n' > "$FAKE_PRIVATE/seed"
  git -C "$FAKE_PRIVATE" add -A
  git -C "$FAKE_PRIVATE" commit -qm "init"
  git -C "$FAKE_PRIVATE" remote add origin "$FAKE_SCRATCH/origin.git"
  git -C "$FAKE_PRIVATE" push -q -u origin HEAD
}

# Write a file whose CONTENT looks like a credential, without this test file
# itself containing one.
#
# The fixture is assembled from fragments on purpose. Written as a literal, the
# fail-closed gitleaks pre-commit hook rejects the commit — correctly, since a
# JWT-shaped string in a repo is indistinguishable from a real leak at scan
# time. A test fixture is not a reason to weaken that hook.
write_credential_shaped_file() {
  local dest="$1" token
  token="ey"'J'"hbGciOiJIUzI1NiJ9"."ey"'J'"pZCI6MX0"."c2lnbmF0dXJl"
  mkdir -p "$(dirname "$dest")"
  printf '{"jwt":"%s"}\n' "$token" > "$dest"
}

# Run dot-adopt against the sandbox. DOTFILES_ROOT stays real so lib/log.sh
# resolves; HOME and DOTFILES_PRIVATE are redirected.
run_adopt() {
  run env HOME="$FAKE_HOME" \
          DOTFILES_ROOT="$REPO_ROOT" \
          DOTFILES_PRIVATE="$FAKE_PRIVATE" \
          "$ADOPT" "$@"
}

# ── Happy path ────────────────────────────────────────────────────────────────

@test "adopt moves the file, writes the mapping, and stages it" {
  run_adopt adopt "$FAKE_HOME/.plainfile"
  [ "$status" -eq 0 ]

  # Moved, not copied — the original must be gone so Home Manager can own it.
  [ ! -e "$FAKE_HOME/.plainfile" ]
  [ -f "$FAKE_PRIVATE/home/.plainfile" ]

  # A path literal, not an interpolated string: only the literal is copied into
  # the store as flake source and evaluates purely.
  grep -qF '".plainfile".source = ./home/.plainfile;' "$FAKE_PRIVATE/home.nix"

  # R2: the flake evaluator ignores untracked files, so an unstaged adoption
  # is invisible and fails confusingly at rebuild time.
  run git -C "$FAKE_PRIVATE" diff --cached --name-only
  [[ "$output" == *"home/.plainfile"* ]]
  [[ "$output" == *"home.nix"* ]]
}

@test "--mutable writes an out-of-store symlink so the file stays writable" {
  # A read-only /nix/store symlink is wrong for any file its own application
  # rewrites — editor and CLI settings.json files. The app hits a read-only
  # path and silently fails to save. mkOutOfStoreSymlink points at the real
  # file in the private repo instead: writable, and edits land in git.
  run_adopt adopt "$FAKE_HOME/.plainfile" --mutable
  [ "$status" -eq 0 ]

  [ ! -e "$FAKE_HOME/.plainfile" ]
  [ -f "$FAKE_PRIVATE/home/.plainfile" ]

  grep -qF 'config.lib.file.mkOutOfStoreSymlink' "$FAKE_PRIVATE/home.nix"
  # homeDirectory, not a baked-in /Users/<name>, or the entry breaks on a
  # second Mac with a different username.
  grep -qF '${config.home.homeDirectory}' "$FAKE_PRIVATE/home.nix"
  # A store-path source would defeat the whole point.
  run grep -qF '".plainfile".source = ./home/.plainfile;' "$FAKE_PRIVATE/home.nix"
  [ "$status" -ne 0 ]

  # mkOutOfStoreSymlink needs `config` in scope; a `{ ... }:` stub fails to eval.
  grep -qE '^\{ config, \.\.\. \}:' "$FAKE_PRIVATE/home.nix"
}

@test "a path containing spaces is adoptable" {
  # Every macOS application config lives under "Library/Application Support".
  # The original character class excluded spaces, so `dot adopt` could not
  # touch a single app preference file on the platform it targets.
  mkdir -p "$FAKE_HOME/Library/Application Support/Cursor/User"
  printf '{}\n' > "$FAKE_HOME/Library/Application Support/Cursor/User/settings.json"

  run_adopt adopt "$FAKE_HOME/Library/Application Support/Cursor/User/settings.json" --mutable
  [ "$status" -eq 0 ]
  [ -f "$FAKE_PRIVATE/home/Library/Application Support/Cursor/User/settings.json" ]
  grep -qF '"Library/Application Support/Cursor/User/settings.json".source' "$FAKE_PRIVATE/home.nix"
}

@test "adopt still refuses a path that would escape its Nix string" {
  # Widening valid_rel to allow spaces must not allow quote/interpolation
  # characters, which would break out of the generated Nix string.
  printf 'x\n' > "$FAKE_HOME/bad\${oops}"
  run_adopt adopt "$FAKE_HOME/bad\${oops}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be safely quoted"* ]]
  [ -e "$FAKE_HOME/bad\$={oops}" ] || [ -e "$FAKE_HOME/bad\${oops}" ]
}

@test "adopt leaves the private repo uncommitted" {
  run_adopt adopt "$FAKE_HOME/.plainfile"
  [ "$status" -eq 0 ]
  # Committing someone's private repo for them is not this tool's call.
  run git -C "$FAKE_PRIVATE" log --oneline
  [ "$status" -ne 0 ]
}

@test "dry-run reports the plan without touching anything" {
  run_adopt adopt "$FAKE_HOME/.plainfile" --dry-run
  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.plainfile" ]
  [ ! -e "$FAKE_PRIVATE/home/.plainfile" ]
  [ ! -f "$FAKE_PRIVATE/home.nix" ]
}

# ── Refusals ──────────────────────────────────────────────────────────────────

@test "adopt refuses a path that does not exist" {
  run_adopt adopt "$FAKE_HOME/.nope"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "adopt refuses a path outside \$HOME" {
  outside="$(mktemp -t dot_adopt_outside.XXXXXX)"
  run_adopt adopt "$outside"
  rm -f "$outside"
  [ "$status" -ne 0 ]
  [[ "$output" == *"outside \$HOME"* ]]
}

@test "adopt refuses credential material" {
  mkdir -p "$FAKE_HOME/.ssh"
  printf 'Host example\n' > "$FAKE_HOME/.ssh/config"
  run_adopt adopt "$FAKE_HOME/.ssh/config"
  [ "$status" -ne 0 ]
  [[ "$output" == *"credential material"* ]]
  # Still in place: a refusal must never be a half-move.
  [ -f "$FAKE_HOME/.ssh/config" ]
}

@test "adopt refuses a path already symlinked into /nix/store" {
  ln -s /nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-x/config "$FAKE_HOME/.managed"
  run_adopt adopt "$FAKE_HOME/.managed"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Already managed"* ]]
}

@test "adopt refuses a path already pointing into the private repo" {
  mkdir -p "$FAKE_PRIVATE/home"
  printf 'x\n' > "$FAKE_PRIVATE/home/.already"
  ln -s "$FAKE_PRIVATE/home/.already" "$FAKE_HOME/.already"
  run_adopt adopt "$FAKE_HOME/.already"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Already adopted"* ]]
}

@test "adopt refuses when the destination is already occupied" {
  mkdir -p "$FAKE_PRIVATE/home"
  printf 'previous\n' > "$FAKE_PRIVATE/home/.plainfile"
  run_adopt adopt "$FAKE_HOME/.plainfile"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Destination already exists"* ]]
  # The occupying copy must not be clobbered.
  grep -q previous "$FAKE_PRIVATE/home/.plainfile"
}

@test "adopt is not repeatable against the same path" {
  run_adopt adopt "$FAKE_HOME/.plainfile"
  [ "$status" -eq 0 ]
  # Recreate the home path as if the operator restored it by hand.
  printf 'contract\n' > "$FAKE_HOME/.plainfile"
  run_adopt adopt "$FAKE_HOME/.plainfile"
  [ "$status" -ne 0 ]
}

# ── The Home Manager collision guard ──────────────────────────────────────────

@test "adopt refuses a directory containing Home Manager symlinks" {
  # Mirrors the real ~/.config/nvim: a real directory holding one store symlink
  # alongside unmanaged files. Adopting the directory would move that store
  # link into the private repo and give the path two owners.
  mkdir -p "$FAKE_HOME/.config/nvim"
  ln -s /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-hm/init.lua \
        "$FAKE_HOME/.config/nvim/init.lua"
  printf '{}\n' > "$FAKE_HOME/.config/nvim/lazy-lock.json"

  run_adopt adopt "$FAKE_HOME/.config/nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Home Manager symlink"* ]]
  [ -L "$FAKE_HOME/.config/nvim/init.lua" ]
}

@test "the unmanaged file inside such a directory is still adoptable" {
  mkdir -p "$FAKE_HOME/.config/nvim"
  ln -s /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-hm/init.lua \
        "$FAKE_HOME/.config/nvim/init.lua"
  printf '{}\n' > "$FAKE_HOME/.config/nvim/lazy-lock.json"

  run_adopt adopt "$FAKE_HOME/.config/nvim/lazy-lock.json"
  [ "$status" -eq 0 ]
  [ -f "$FAKE_PRIVATE/home/.config/nvim/lazy-lock.json" ]
  grep -qF '".config/nvim/lazy-lock.json".source' "$FAKE_PRIVATE/home.nix"
}

# ── scan-unmapped ─────────────────────────────────────────────────────────────

@test "scan-unmapped lists candidates and never risks secret or managed paths" {
  mkdir -p "$FAKE_HOME/.ssh" "$FAKE_HOME/.cache"
  printf 'k\n' > "$FAKE_HOME/.ssh/id_rsa"
  printf 'c\n' > "$FAKE_HOME/.cache/blob"
  ln -s /nix/store/cccccccccccccccccccccccccccccccc-x/zshrc "$FAKE_HOME/.zshrc"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]

  # The candidate is reported as something you would lose.
  lost="${output##*would be LOST}"
  [[ "$lost" == *".plainfile"* ]]

  # Skipped paths must never be RECOMMENDED. They are now printed, with a
  # reason, under "Deliberately skipped" — this assertion used to demand they
  # be absent from the output entirely, which is what let the old version hide
  # its decisions and offer credentials by omission of any explanation.
  [[ "$lost" != *".ssh"* ]]
  [[ "$lost" != *".zshrc"* ]]
  [[ "$lost" != *".cache"* ]]

  # And the reasoning is visible rather than silent.
  [[ "$output" == *"Deliberately skipped"* ]]
  [[ "$output" == *".ssh"* ]]
}

@test "scan finds config under Library/Application Support" {
  # The scan walked only ~/.* and ~/.config, so on macOS — the only platform
  # this framework targets — it could not see where GUI apps actually keep
  # settings. Six editor config files were invisible to every scan ever run.
  mkdir -p "$FAKE_HOME/Library/Application Support/Cursor/User"
  printf '{"editor.fontSize":16}\n' \
    > "$FAKE_HOME/Library/Application Support/Cursor/User/settings.json"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cursor/User/settings.json"* ]]
}

@test "scan does not offer extension payload directories" {
  # ~/.cursor, ~/.vscode-insiders, ~/.devin and ~/.windsurf are ~3 GB of
  # reinstallable extensions between them, and every one was reported as
  # "available to adopt" because classification was a filename list.
  mkdir -p "$FAKE_HOME/.someeditor/extensions/pkg"
  printf 'x\n' > "$FAKE_HOME/.someeditor/extensions/pkg/blob.bin"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"reinstallable"* ]]
  # It must not appear in the "would be LOST" list.
  lost="${output##*would be LOST}"
  [[ "$lost" != *".someeditor"* ]]
}

@test "scan detects a credential inside a blandly named file" {
  # Not hypothetical: ~/.software/extensions.json holds a live JWT. A
  # filename-only check offered that directory for adoption — i.e. recommended
  # committing a working token to git.
  write_credential_shaped_file "$FAKE_HOME/.someapp/extensions.json"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"credential-shaped content"* ]]
  lost="${output##*would be LOST}"
  [[ "$lost" != *".someapp"* ]]
}

@test "adopt refuses a credential the scan would not recommend" {
  # The scan declining to suggest a path is worthless if `dot adopt <path>`
  # still moves it into git without comment. Both commands share one check.
  write_credential_shaped_file "$FAKE_HOME/.someapp/extensions.json"

  run_adopt adopt "$FAKE_HOME/.someapp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"credential"* ]]
  # Refusal must not have moved anything.
  [ -f "$FAKE_HOME/.someapp/extensions.json" ]
  [ ! -e "$FAKE_PRIVATE/home/.someapp" ]
}

@test "scan ignores empty directories" {
  # Four of five editor `snippets/` dirs on a real machine are empty. Listing
  # them as things you would "lose" is noise that hides the real answer.
  mkdir -p "$FAKE_HOME/.emptyconfig"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" != *".emptyconfig"* ]]
}

# ── "would anything be lost" must account for the repo, not just $HOME ───────
#
# The verdict reasoned only about $HOME and home.nix: adopt every candidate and
# it printed "Nothing would be lost. Every config found is backed up." while
# the repo holding those files had never been pushed anywhere. On the machine
# this was found on it was 14 commits ahead of a remote that had never seen
# them — a confident reassurance covering a total loss.

@test "scan reports unpushed private commits as AT RISK" {
  publish_private_sandbox
  git -C "$FAKE_PRIVATE" commit -q --allow-empty -m "adopted something"
  git -C "$FAKE_PRIVATE" commit -q --allow-empty -m "adopted something else"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"AT RISK"* ]]
  [[ "$output" == *"2 commit(s) exist only on this Mac"* ]]
  [[ "$output" != *"Nothing would be lost"* ]]
}

@test "scan reports a private repo with no remote as backed up to nowhere" {
  # setup() leaves FAKE_PRIVATE with no origin — the state of anyone who has
  # not created their private GitHub repo yet.
  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"AT RISK"* ]]
  [[ "$output" == *"backed up to NOWHERE"* ]]
  [[ "$output" != *"Nothing would be lost"* ]]
}

@test "scan reports uncommitted private changes as AT RISK" {
  # `dot adopt` stages what it moves but does not commit it. A staged-only
  # adoption is on exactly one disk.
  publish_private_sandbox
  printf 'adopted\n' > "$FAKE_PRIVATE/pending"
  git -C "$FAKE_PRIVATE" add -A

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"AT RISK"* ]]
  [[ "$output" == *"uncommitted change(s)"* ]]
}

@test "scan says nothing would be lost only when the private repo is published" {
  # The one state that earns the reassurance: no candidates left in $HOME AND
  # a private repo that is clean and fully pushed.
  publish_private_sandbox
  rm -f "$FAKE_HOME/.plainfile"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing would be lost"* ]]
  [[ "$output" != *"AT RISK"* ]]
}

@test "scan lists the adopted paths rather than only counting them" {
  # Every adopted path is at least one level deep, so `ls ~` cannot show them.
  # A bare count is a number the user has no way to check.
  publish_private_sandbox
  # printf, not a heredoc: bats ends a test body at the first line that is a
  # bare `}`, which Nix source has plenty of.
  printf '{ config, ... }:\n{\n  home.file = {\n    ".claude/CLAUDE.md".source = ./home/.claude/CLAUDE.md;\n  };\n}\n' \
    > "$FAKE_PRIVATE/home.nix"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 config path(s) adopted"* ]]
  [[ "$output" == *".claude/CLAUDE.md"* ]]
}

@test "scan counts adopted paths written in the flat home.file form" {
  # Both forms are valid Nix, and this script advertises the flat one in its
  # own header and in `dot adopt`'s closing hint. A pattern anchored to the
  # nested form drops hand-written entries out of the count AND the list —
  # under-reporting what is protected, which is the direction that hurts.
  publish_private_sandbox
  printf '{ config, ... }:\n{\n  home.file."%s".source = ./home/%s;\n}\n' \
    ".gitconfig" ".gitconfig" > "$FAKE_PRIVATE/home.nix"

  run_adopt scan-unmapped
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 config path(s) adopted"* ]]
  [[ "$output" == *"~/.gitconfig"* ]]
}

@test "an unknown subcommand fails loudly" {
  run_adopt frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected 'adopt' or 'scan-unmapped'"* ]]
}
