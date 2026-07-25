#!/usr/bin/env bash
# lib/nix.sh — shared Nix invocation setup for every script that shells out to
# `nix` or `darwin-rebuild`. Source it after lib/log.sh.
#
# WHY THIS EXISTS:
#   `hosts/default.nix` sets `nix.settings.experimental-features`, but that only
#   takes effect AFTER a successful build — which is itself a flake command.
#   On a fresh machine the official Nix installer does not enable flakes, so the
#   very first `nix flake lock` / `darwin-rebuild --flake` fails with
#   "experimental Nix feature 'nix-command' is disabled".
#
#   Carrying the feature in NIX_CONFIG breaks that chicken-and-egg without
#   writing to /etc/nix/nix.conf, without sudo, and without leaving state behind
#   on a machine the user may not want us to modify.

# Append rather than overwrite: respect a NIX_CONFIG the caller already set.
if [[ "${NIX_CONFIG:-}" != *"experimental-features"* ]]; then
  export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}experimental-features = nix-command flakes"
fi

# Absolute path to the nix binary. `sudo` does not carry the Nix profile on its
# secure_path, so callers that cross a sudo boundary must pass a full path.
nix_bin() {
  command -v nix 2>/dev/null
}

# Nix system double for this machine. Generated host files must not hardcode
# aarch64-darwin — that produced a flake that could never build on Intel while
# flake.nix simultaneously advertised x86_64-darwin support.
nix_system() {
  case "$(uname -m)" in
    arm64 | aarch64) echo "aarch64-darwin" ;;
    x86_64) echo "x86_64-darwin" ;;
    *) echo "aarch64-darwin" ;;
  esac
}

require_nix() {
  if ! command -v nix >/dev/null 2>&1; then
    log_error "Nix is not installed or not on PATH."
    log_info "Run: ${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/bootstrap"
    return 1
  fi
}
