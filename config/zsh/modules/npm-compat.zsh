# npm-compat.zsh — npm/pnpm interop for pnpm-first environments
# Part of: config/zsh/modules/
#
# Provides:
#   real-npm              — run the real npm binary, bypassing the pnpm alias
#   workshop-npx          — run the real npx binary, bypassing the pnpm alias
#   setup-pnpm-workspace  — write pnpm workspace config for an npm-authored repo
#
# Nothing here runs on directory change. Every function in this file is called
# explicitly, by `workshop` or by the user.
#
# Sourced by bats under bash as well as by zsh, so shell-specific syntax stays
# behind a ZSH_VERSION guard.

# ── real npm / npx resolution ────────────────────────────────────────────────

# Look a command up on PATH only, ignoring aliases and shell functions.
# zsh spells this `whence -p`; bash spells it `type -P`.
_npm_compat_path_lookup() {
  local name="$1" bin
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    bin=$(whence -p "$name" 2>/dev/null)
  else
    bin=$(type -P "$name" 2>/dev/null)
  fi
  [[ -n "$bin" && -x "$bin" ]] || return 1
  printf '%s\n' "$bin"
}

# real-npm — run the genuine npm binary.
#
# Deliberately NOT `pnpm exec npm`. `pnpm exec` exports
# npm_config_user_agent=pnpm/<version>, and npm *inherits* that variable rather
# than overwriting it when it runs a package script. Anything downstream that
# sniffs the user agent to pick a package manager — pkgmgr and pkgmgrx, which
# Epic Web workshops use — then still resolves to pnpm. Routing through pnpm to
# "escape" pnpm cannot work.
#
# Resolution is PATH-based, so pnpm-managed global npm
# (~/.local/share/pnpm/bin/npm) and Homebrew/system npm all work. The previous
# implementation probed only /usr/local/bin, /opt/homebrew/bin and /usr/bin,
# none of which exist on a Nix-managed machine.
real-npm() {
  local bin
  if ! bin=$(_npm_compat_path_lookup npm); then
    echo "real-npm: no npm executable found on PATH." >&2
    echo "  Install one with: pnpm add -g npm" >&2
    return 1
  fi
  "$bin" "$@"
}

# workshop-npx — run the genuine npx binary. Same reasoning as real-npm.
workshop-npx() {
  local bin
  if ! bin=$(_npm_compat_path_lookup npx); then
    echo "workshop-npx: no npx executable found on PATH." >&2
    echo "  Install one with: pnpm add -g npm" >&2
    return 1
  fi
  "$bin" "$@"
}

# ── pnpm workspace generation ────────────────────────────────────────────────

# Packages in an Epic Web workshop that genuinely need their install scripts.
#
# pnpm blocks dependency lifecycle scripts by default and exits non-zero when it
# had to block one. This list was not guessed: it is every package under the
# workshop's node_modules trees (root, epicshop, all 128 exercise apps and the
# playground) declaring an install, preinstall or postinstall script.
#
# esbuild and the prisma packages fetch or generate platform binaries, msw
# writes its service worker, @sentry/* and unrs-resolver pull native artifacts.
# Keeping this explicit rather than using dangerouslyAllowAllBuilds means a new
# script-bearing transitive dependency is surfaced instead of silently trusted.
_epic_built_dependencies() {
  cat <<'EOF'
@prisma/client
@prisma/engines
@sentry/cli
@sentry/node-cpu-profiler
esbuild
msw
prisma
unrs-resolver
EOF
}

# Read the npm `workspaces` field with a real JSON parser.
#
# The previous implementation scraped quoted strings out of package.json with
# grep, which captured the literal key `workspaces` as a package pattern. pnpm
# then treated `workspaces` as a workspace glob and the generated file was
# malformed. Prints one pattern per line; fails loudly rather than guessing.
_epic_workspace_patterns() {
  local pkg_json="$1"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    let pkg;
    try {
      pkg = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (err) {
      console.error("cannot parse " + file + ": " + err.message);
      process.exit(1);
    }
    const field = pkg.workspaces;
    let patterns;
    if (Array.isArray(field)) {
      patterns = field;
    } else if (field && Array.isArray(field.packages)) {
      patterns = field.packages;
    } else if (field === undefined) {
      console.error("no \"workspaces\" field in " + file);
      process.exit(2);
    } else {
      console.error("unsupported \"workspaces\" format in " + file);
      process.exit(2);
    }
    for (const p of patterns) {
      if (typeof p !== "string" || p.trim() === "") {
        console.error("invalid workspace pattern in " + file + ": " + JSON.stringify(p));
        process.exit(3);
      }
    }
    for (const p of patterns) console.log(p);
  ' "$pkg_json"
}

# Emit the shared tail of both generated files.
_epic_workspace_settings() {
  echo ""
  echo "# Exercise apps were authored against npm's flat node_modules and rely on"
  echo "# undeclared transitive dependencies. \"hoisted\" reproduces that layout"
  echo "# while still hardlinking every file from pnpm's store, so disk stays small."
  echo "nodeLinker: hoisted"
  echo ""
  echo "# Scoped to this workshop. See _epic_built_dependencies in npm-compat.zsh."
  echo "#"
  echo "# pnpm 11 spells this 'allowBuilds' and takes a map. The pnpm 10 spelling"
  echo "# 'onlyBuiltDependencies' is silently inert here: pnpm still reports"
  echo "# ERR_PNPM_IGNORED_BUILDS and exits 1."
  echo "allowBuilds:"
  _epic_built_dependencies | while IFS= read -r dep; do
    [[ -n "$dep" ]] && echo "  '$dep': true"
  done
}

# Add paths to a repository's .git/info/exclude.
#
# Local-only ignores: the tracked .gitignore is never modified, so `git pull`
# for workshop updates stays clean. Idempotent — an entry is appended only when
# an exact line match is absent.
_epic_git_exclude() {
  local root="$1"
  shift

  local git_dir
  git_dir=$(git -C "$root" rev-parse --git-dir 2>/dev/null) || return 0
  case "$git_dir" in
    /*) ;;
    *) git_dir="$root/$git_dir" ;;
  esac

  local exclude_file="$git_dir/info"
  mkdir -p "$exclude_file" 2>/dev/null || return 0
  exclude_file="$exclude_file/exclude"

  local entry
  for entry in "$@"; do
    if ! grep -qxF "$entry" "$exclude_file" 2>/dev/null; then
      printf '%s\n' "$entry" >> "$exclude_file"
    fi
  done
}

# setup-pnpm-workspace — write both pnpm workspace files for a workshop.
#
# Idempotent: the generated content is a pure function of package.json, so
# re-running rewrites identical bytes.
#
# The nested epicshop/pnpm-workspace.yaml is a mandatory recursion guard, not a
# nicety. The workshop root's package.json declares
#   "postinstall": "cd ./epicshop && pkgmgr install"
# and without a workspace boundary inside ./epicshop, pnpm walks up to the
# workshop root, decides the root is the install target, and re-fires that same
# postinstall — recursing until the machine dies.
setup-pnpm-workspace() {
  local root="${1:-.}"

  if [[ ! -f "$root/package.json" ]]; then
    echo "setup-pnpm-workspace: no package.json in $root" >&2
    return 1
  fi

  local patterns
  if ! patterns=$(_epic_workspace_patterns "$root/package.json"); then
    echo "setup-pnpm-workspace: could not read workspace patterns; refusing to" >&2
    echo "  write a pnpm-workspace.yaml that would be wrong." >&2
    return 1
  fi

  {
    echo "# Generated by 'workshop setup' (dotfiles: config/zsh/modules/npm-compat.zsh)."
    echo "# Local-only: registered in .git/info/exclude, never committed."
    echo "#"
    echo "# Mirrors the npm \"workspaces\" field in package.json, which pnpm does"
    echo "# not read. Without it pnpm installs the root dependencies only and"
    echo "# silently skips every exercise app."
    echo "packages:"
    if [[ -n "$patterns" ]]; then
      printf '%s\n' "$patterns" | while IFS= read -r pattern; do
        [[ -n "$pattern" ]] && echo "  - '$pattern'"
      done
    else
      echo "  []"
    fi
    _epic_workspace_settings
  } > "$root/pnpm-workspace.yaml"

  if [[ -d "$root/epicshop" ]]; then
    {
      echo "# Generated by 'workshop setup'. LOAD-BEARING — do not delete."
      echo "#"
      echo "# The workshop root runs 'cd ./epicshop && pkgmgr install' as its"
      echo "# postinstall. Without a workspace boundary here, pnpm climbs to the"
      echo "# workshop root, installs that instead, and re-fires the same"
      echo "# postinstall in an unbounded fork bomb. An empty package list makes"
      echo "# ./epicshop its own workspace root so the install terminates."
      echo "packages: []"
      _epic_workspace_settings
    } > "$root/epicshop/pnpm-workspace.yaml"

    # Explicit arguments, not an accumulated string: zsh does not word-split
    # unquoted parameters, so a "a b" accumulator arrives as one argument and
    # writes a single malformed exclude line. bash splits it and hides the bug.
    _epic_git_exclude "$root" "pnpm-workspace.yaml" "epicshop/pnpm-workspace.yaml"
    echo "Wrote: pnpm-workspace.yaml epicshop/pnpm-workspace.yaml"
  else
    _epic_git_exclude "$root" "pnpm-workspace.yaml"
    echo "Wrote: pnpm-workspace.yaml"
  fi
}
