#!/usr/bin/env bash
# lib/private-flake.sh — shared shape of the private downstream flake
#
# Two scripts write into ~/dotfiles-private and must agree on its layout:
#
#   scripts/bin/setup-private-host  creates the flake, the hosts/ directory and
#                                   the home.nix stub the host file imports
#   scripts/bin/dot-adopt           appends home.file mappings to that home.nix
#
# They previously each carried their own copy of the home.nix heredoc — and only
# dot-adopt's had the insertion sentinel, so a freshly generated private flake
# had no home.nix at all and the first `dot adopt` had to create one that the
# host file did not import. Both now call into here.

# Insertion marker. `dot adopt` puts new mappings directly above this line, so
# appending never has to parse the surrounding attribute set to find its end.
DOT_ADOPT_SENTINEL="# dot-adopt:entries — new mappings are inserted directly above this line."

# Subdirectory of the private flake that adopted files are moved into.
DOT_ADOPT_SUBDIR="home"

# write_home_nix_stub <home.nix path> — no-op when the file already exists, so
# it is safe to call from both scripts and on every re-run.
write_home_nix_stub() {
  local home_nix="$1"
  [[ -f "$home_nix" ]] && return 0

  mkdir -p "$(dirname "$home_nix")"
  cat > "$home_nix" <<EOF
# Home Manager mappings for files adopted out of \$HOME.
#
# Generated and appended to by \`dot adopt\`. Each entry moves a real file into
# ./$DOT_ADOPT_SUBDIR/ and hands ownership of the \$HOME path to Home Manager.
# There are two kinds of entry:
#
#   .source = ./$DOT_ADOPT_SUBDIR/<path>
#       Copied into /nix/store and deployed as a READ-ONLY symlink. Immutable
#       and reproducible. Edit the copy under ./$DOT_ADOPT_SUBDIR/ and run
#       \`dot rebuild\`; the deployed file cannot be written.
#
#   .source = config.lib.file.mkOutOfStoreSymlink "\${config.home.homeDirectory}/..."
#       Written by \`dot adopt --mutable\`. Deployed as a symlink pointing at the
#       real file in THIS repository rather than at a store copy, so the file
#       stays writable: the application saves its own settings, the change lands
#       here, and \`git diff\` shows it. Use this for anything an app rewrites
#       (editor and CLI settings.json files) — a read-only symlink makes those
#       apps fail to save.
#
# Both kinds are versioned here and both travel to your next Mac. The mutable
# form assumes this repository is at \${config.home.homeDirectory}/dotfiles-private.
#
# This file is imported by hosts/<hostname>.nix. It is valid while empty, which
# is the point: the import exists from the moment the private flake is created,
# so the first \`dot adopt\` deploys without a manual host-file edit.
{ config, ... }:

{
  home.file = {
    $DOT_ADOPT_SENTINEL
  };
}
EOF
}
