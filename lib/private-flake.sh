#!/usr/bin/env bash
# lib/private-flake.sh — shared shape of the private downstream flake
#
# setup-private-host and dot-adopt both write into ~/dotfiles-private and must
# agree on where adopted files live. Existing profiles use home/<path>; readable
# modular profiles use home/files/<path> and import the generated root home.nix
# from home/default.nix.

# Insertion marker. `dot adopt` puts new mappings directly above this line, so
# appending never has to parse the surrounding attribute set to find its end.
DOT_ADOPT_SENTINEL="# dot-adopt:entries — new mappings are inserted directly above this line."

# Print the private-profile layout understood by the compatibility layer.
#
# A modular profile always has home/default.nix. Existing profiles deliberately
# remain legacy until they are migrated; a plain home/ directory is not enough
# evidence because it already stores adopted files in the old layout.
private_profile_layout() {
  local root="${1:-${PRIVATE_ROOT:-}}"

  if [[ -n "$root" && -f "$root/home/default.nix" ]]; then
    printf 'modular\n'
  else
    printf 'legacy\n'
  fi
}

# Subdirectory of the private flake that adopted files are moved into. Resolve it
# when this library is sourced: dot-adopt has already set PRIVATE_ROOT by then.
if [[ "$(private_profile_layout)" == "modular" ]]; then
  DOT_ADOPT_SUBDIR="home/files"
else
  DOT_ADOPT_SUBDIR="home"
fi

# write_home_nix_stub <home.nix path> — no-op when the file already exists, so
# it is safe to call from setup-private-host and dot-adopt on every re-run.
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
# This file is imported by the private Home Manager configuration. It is valid
# while empty, so the first \`dot adopt\` deploys without a manual module edit.
{ config, ... }:

{
  home.file = {
    $DOT_ADOPT_SENTINEL
  };
}
EOF
}
