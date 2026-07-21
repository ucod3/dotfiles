# lib/local.nix — Impure-aware loader for the gitignored `.local/` settings layer
#
# WHY THIS EXISTS (empirically verified, see AGENTS.md "Local Settings Layer"):
#   * `.local/` is gitignored. Inside a `git+file:` flake, relative reads like
#     `builtins.pathExists ./.local/...` silently evaluate to `false` because
#     untracked files are excluded from the Nix store evaluation copy.
#   * The `path:` scheme is NOT a safe workaround: it copies `.git/` into the
#     store and hard-fails on `.git/fsmonitor--daemon.ipc` (this repo enables
#     `core.fsmonitor`). With `.local` as an out-of-tree symlink it still
#     resolves to MISSING under pure evaluation.
#   * The only pattern that works for BOTH a plain gitignored directory and a
#     `.local -> ~/dotfiles-private` symlink is an absolute-path read under
#     `--impure`. `scripts/bin/rebuild` passes the flag and exports
#     `DOTFILES_LOCAL` explicitly (sudo may rewrite $HOME).
#
# PURITY CONTRACT:
#   Under pure evaluation (`nix flake check`, CI, cold clones) `getEnv`
#   returns "" and this loader degrades to empty settings — every optional
#   set stays disabled and evaluation succeeds. Nothing here throws.
#
# SETTINGS SCHEMA (all keys optional):
#   .local/identity.nix           { name = "..."; email = "..."; }
#   .local/settings.nix           { ai.enable = bool; apps.<set>.enable = bool;
#                                   casks = [ ... ]; nixPackages = [ ... ]; }
#   .local/browsers/choices.nix   { casks = [ ... ]; nixPackages = [ ... ]; }
#   .local/editors/choices.nix    { casks = [ ... ]; nixPackages = [ ... ]; }
#   .local/hosts/                 reserved for the private flake (never
#                                 auto-imported here, to avoid double imports)

let
  # Resolution order: explicit override → <repo>/.local → ~/dotfiles-private
  envLocal = builtins.getEnv "DOTFILES_LOCAL";
  home = builtins.getEnv "HOME";

  candidates =
    (if envLocal != "" then [ envLocal ] else [ ])
    ++ (if home != "" then [
      "${home}/dotfiles/.local"
      "${home}/dotfiles-private"
    ] else [ ]);

  # Convert an absolute path string to a path value (works under --impure)
  toAbsPath = s: /. + s;

  firstExisting = paths:
    if paths == [ ] then null
    else if builtins.pathExists (toAbsPath (builtins.head paths))
    then builtins.head paths
    else firstExisting (builtins.tail paths);

  dir = firstExisting candidates;

  importIfPresent = rel:
    if dir != null && builtins.pathExists (toAbsPath "${dir}/${rel}")
    then import (toAbsPath "${dir}/${rel}")
    else { };

  settings = importIfPresent "settings.nix";
  browsers = importIfPresent "browsers/choices.nix";
  editors = importIfPresent "editors/choices.nix";
  identityRaw = importIfPresent "identity.nix";
in
{
  # True only when a local settings layer was found (always false in pure eval)
  exists = dir != null;
  inherit dir settings;

  identity = if identityRaw == { } then null else identityRaw;

  # Flattened selections written by the interactive installer
  casks =
    (settings.casks or [ ])
    ++ (browsers.casks or [ ])
    ++ (editors.casks or [ ]);
  nixPackages =
    (settings.nixPackages or [ ])
    ++ (browsers.nixPackages or [ ])
    ++ (editors.nixPackages or [ ]);

  # Toggle helpers with safe fallbacks
  appEnabled = set: settings.apps.${set}.enable or false;
  aiEnabled = settings.ai.enable or false;
}
