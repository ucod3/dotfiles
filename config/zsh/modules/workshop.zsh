# Workshop-specific logic for Epic Web workshops
#
# Three commands carry the workflow:
#   workshop setup    once per workshop — writes config, installs
#   workshop start    every day after that
#   workshop status   read-only inspection
#
# Directory detection (epic-detect) is strictly read-only. It reports state and
# names the next command; it never writes a file, installs, or changes
# package-manager state.
#
# Sourced by bats under bash as well as by zsh, so shell-specific syntax stays
# behind a ZSH_VERSION guard.

# ── read-only inspection helpers ─────────────────────────────────────────────

# True in an interactive shell. Split out so bats can drive the chpwd hooks
# under bash, where `[[ -o interactive ]]` is not a valid option test.
_epic_shell_is_interactive() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ -o interactive ]]
  else
    case "$-" in
      *i*) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# True when $1 (default .) is an Epic Web workshop root.
_epic_is_workshop() {
  local root="${1:-.}"
  [[ -f "$root/package.json" ]] || return 1
  grep -q '"epicshop"' "$root/package.json" 2>/dev/null
}

# Echo the package-manager layout of a node_modules directory:
#   missing | npm | pnpm | mixed
#
# npm writes node_modules/.package-lock.json; pnpm writes node_modules/.modules.yaml.
# Both present means one manager was run over the other's tree, which produces
# the half-npm/half-pnpm state that breaks module resolution in ways that look
# like unrelated application bugs.
_epic_layout() {
  local nm="$1"
  [[ -d "$nm" ]] || { echo "missing"; return 0; }

  local has_npm=false has_pnpm=false
  [[ -f "$nm/.package-lock.json" ]] && has_npm=true
  [[ -f "$nm/.modules.yaml" ]] && has_pnpm=true

  if $has_npm && $has_pnpm; then
    echo "mixed"
  elif $has_pnpm; then
    echo "pnpm"
  elif $has_npm; then
    echo "npm"
  else
    echo "missing"
  fi
}

# True when both generated workspace files are present and the nested one
# actually establishes the recursion boundary.
_epic_is_configured() {
  local root="${1:-.}"
  [[ -f "$root/pnpm-workspace.yaml" ]] || return 1
  [[ -f "$root/epicshop/pnpm-workspace.yaml" ]] || return 1
  grep -q '^packages: *\[\] *$' "$root/epicshop/pnpm-workspace.yaml" 2>/dev/null
}

# Classify the workshop's declared setup work relative to what `pnpm install`
# already does. Echoes one of:
#
#   none     no setup script, or one whose only action is the install
#   custom   a setup:custom script exists — extra work beyond the install
#   unknown  a setup script this helper does not recognise
#
# `epicshop setup` (dist/commands/setup.js) does exactly two things: it runs
# `pkgmgr install`, then, only if scripts["setup:custom"] exists, it runs
# `npm run setup:custom`. The install half is what `workshop setup` already
# performs, so a workshop with no setup:custom is fully covered. Anything else
# is reported rather than assumed.
_epic_setup_script_kind() {
  local root="${1:-.}"
  node -e '
    const fs = require("fs");
    let scripts = {};
    try {
      scripts = (JSON.parse(fs.readFileSync(process.argv[1], "utf8")).scripts) || {};
    } catch { console.log("unknown"); process.exit(0); }

    const setup = scripts.setup;
    const custom = scripts["setup:custom"];

    // Every runner spelling (pkgmgrx / npx / pnpm dlx / bunx) ends in the same
    // command, so a substring test covers them all without enumerating runners.
    const knownSetup = typeof setup === "string" && setup.includes("epicshop setup");

    if (!setup) { console.log(custom ? "custom" : "none"); process.exit(0); }
    if (!knownSetup) { console.log("unknown"); process.exit(0); }
    console.log(custom ? "custom" : "none");
  ' "$root/package.json" 2>/dev/null || echo unknown
}

# Count workshop apps that declare a prisma schema but have no generated client.
#
# pnpm runs a dependency's install script once per store instance, not once per
# workspace, so @prisma/client's postinstall generates a client in a single app.
# The workshop's setup:custom runs `prisma generate` in every app; without it
# the remaining apps have a schema and no client.
_epic_prisma_pending() {
  local root="${1:-.}" pending=0 schema app
  while IFS= read -r schema; do
    [[ -n "$schema" ]] || continue
    app="${schema%/prisma/schema.prisma}"
    [[ -d "$app/node_modules/.prisma/client" ]] || pending=$((pending + 1))
  done <<EOF
$(find "$root/exercises" "$root/examples" "$root/playground" -maxdepth 4 -path '*/prisma/schema.prisma' -not -path '*/node_modules/*' 2>/dev/null)
EOF
  echo "$pending"
}

# Echo the state of setup work beyond the install:
#   none | satisfied | unknown | "pending <count>"
#
# The pending count rides along with the state so callers that report it do not
# have to walk the tree a second time.
_epic_custom_setup_state() {
  local root="${1:-.}" kind pending
  kind=$(_epic_setup_script_kind "$root")
  case "$kind" in
    none) echo "none" ;;
    custom)
      pending=$(_epic_prisma_pending "$root")
      if [[ "$pending" -eq 0 ]]; then
        echo "satisfied"
      else
        echo "pending $pending"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}

# True when $2 is registered in $1's .git/info/exclude.
_epic_is_excluded() {
  local root="$1" entry="$2"
  local git_dir
  git_dir=$(git -C "$root" rev-parse --git-dir 2>/dev/null) || return 1
  case "$git_dir" in
    /*) ;;
    *) git_dir="$root/$git_dir" ;;
  esac
  grep -qxF "$entry" "$git_dir/info/exclude" 2>/dev/null
}

# Run the workshop's start script with npm-compatible pkgmgrx routing.
#
# The start script is
#   pkgmgrx --prefix ./epicshop epicshop start
# pkgmgrx picks its package manager from npm_config_user_agent, so under pnpm it
# maps to `pnpm dlx`. `--prefix` is an npx flag; pnpm dlx ignores it, fetches a
# standalone epicshop from the store, and that copy cannot resolve its
# undeclared `zod` dependency. PKGMGR=npm makes pkgmgrx use `npx --prefix`,
# which runs the locally installed binary.
#
# START ONLY — deliberately not used for setup, install, or any script that may
# install. PKGMGR is read by `pkgmgr` (install) as well as `pkgmgrx` (exec), and
# it is inherited by grandchildren. `pnpm run setup` runs `epicshop setup`,
# which itself shells out to `pkgmgr install`; with PKGMGR=npm exported that
# became a real `npm install` running over the pnpm tree, producing exactly the
# mixed npm/pnpm layout `workshop setup` refuses to install into.
_epic_start_with_npm_routing() {
  local -x PKGMGR=npm
  pnpm "$@"
}

# ── workshop command ─────────────────────────────────────────────────────────

workshop() {
  local cmd="$1"
  [[ $# -gt 0 ]] && shift

  case "$cmd" in
    ""|help|-h|--help)
      cat <<'EOF'
Workshop Helper — Epic Web workshops on pnpm

First use:
  workshop setup      Write pnpm config and install dependencies
  workshop start      Run the workshop

Later:
  workshop start      Run the workshop

Inspection:
  workshop status     Report configuration and dependency state (read-only)

Also available:
  workshop ex NUM     Run a specific exercise
  workshop run CMD    Run a package script with pnpm
  workshop npm CMD    Run a real npm command
  workshop npx CMD    Run a real npx command
EOF
      return 0
      ;;
  esac

  if [[ ! -f "./package.json" ]]; then
    echo "Error: no package.json in the current directory" >&2
    return 1
  fi

  case "$cmd" in
    setup)  _workshop_setup "$@" ;;
    start|dev) _workshop_start "$@" ;;
    status) _workshop_status "$@" ;;

    ex|exercise)
      if ! _epic_is_workshop .; then
        echo "Error: 'ex' is only available for Epic Web workshops" >&2
        return 1
      fi
      local ex_num="$1"
      if [[ -z "$ex_num" ]]; then
        echo "Error: please provide an exercise number" >&2
        echo "Usage: workshop ex <number>" >&2
        return 1
      fi
      local ex_dir
      ex_dir=$(find ./exercises -type d -name "*$ex_num.*problem*" 2>/dev/null | head -n 1)
      if [[ -z "$ex_dir" ]]; then
        echo "Error: could not find exercise $ex_num" >&2
        return 1
      fi
      echo "Running exercise $ex_num at: $ex_dir"
      cd "$ex_dir" || return 1
      pnpm run dev
      ;;

    run) pnpm run "$@" ;;
    npm) real-npm "$@" ;;
    npx) workshop-npx "$@" ;;

    *)
      echo "Unknown command: $cmd" >&2
      workshop help
      return 1
      ;;
  esac
}

# Report setup work the install does not cover, and fail if there is any.
#
# Never runs the workshop's setup script itself. `epicshop setup` would re-run
# `pkgmgr install` (already done) and reaching it needs PKGMGR=npm, which its
# nested install inherits and uses to npm-install over the pnpm tree.
# setup:custom additionally runs `playwright install --with-deps`, which may ask
# for admin privileges. Both are reported for the user to run deliberately.
_epic_report_custom_setup() {
  local root="${1:-.}" state n
  state=$(_epic_custom_setup_state "$root")
  n="${state#* }"

  case "${state%% *}" in
    none|satisfied) return 0 ;;
    pending)
      echo "" >&2
      echo "Dependencies installed, but this workshop declares setup work the install" >&2
      echo "does not cover. $n app(s) have a prisma schema and no generated client." >&2
      echo "" >&2
      echo "pnpm runs a dependency's install script once per store instance, not once" >&2
      echo "per workspace, so 'prisma generate' still has to run in each app." >&2
      echo "" >&2
      echo "Run the workshop's own setup script, then start:" >&2
      echo "" >&2
      echo "  SKIP_PLAYWRIGHT=1 pnpm run setup:custom" >&2
      echo "  workshop start" >&2
      echo "" >&2
      echo "SKIP_PLAYWRIGHT=1 skips 'playwright install --with-deps', which may ask for" >&2
      echo "admin privileges and is only needed to run the workshop's tests." >&2
      return 1
      ;;
    *)
      echo "" >&2
      echo "Dependencies installed, but this workshop's setup script is not one this" >&2
      echo "helper recognises. The remaining setup requires manual handling." >&2
      echo "" >&2
      echo "Inspect it with:" >&2
      echo "  node -e \"console.log(require('./package.json').scripts)\"" >&2
      return 1
      ;;
  esac
}

# ── workshop setup ───────────────────────────────────────────────────────────

_workshop_setup() {
  if ! _epic_is_workshop .; then
    echo "Error: this is not an Epic Web workshop (no \"epicshop\" key in package.json)" >&2
    return 1
  fi

  if [[ ! -f "./epicshop/package.json" ]]; then
    echo "Error: ./epicshop/package.json is missing — the workshop checkout is incomplete" >&2
    return 1
  fi

  # Refuse to install over a half-npm/half-pnpm tree. Cleanup deletes the user's
  # files, so it is described rather than performed.
  local root_layout epicshop_layout
  root_layout=$(_epic_layout ./node_modules)
  epicshop_layout=$(_epic_layout ./epicshop/node_modules)

  if [[ "$root_layout" == "mixed" || "$epicshop_layout" == "mixed" ]]; then
    echo "Mixed npm/pnpm dependency layout detected." >&2
    echo "Cleanup is required before setup." >&2
    echo "" >&2
    echo "Both an npm marker (.package-lock.json) and a pnpm marker (.modules.yaml)" >&2
    echo "are present in the same node_modules. Remove the installed trees and" >&2
    echo "re-run setup:" >&2
    echo "" >&2
    echo "  rm -rf node_modules epicshop/node_modules exercises/*/*/node_modules" >&2
    echo "  workshop setup" >&2
    return 1
  fi

  echo "Configuring pnpm workspace..."
  setup-pnpm-workspace . || return 1

  # Plain pnpm: PKGMGR stays unset so the root postinstall
  # ("cd ./epicshop && pkgmgr install") also resolves to pnpm. This single
  # install covers the root, every exercise workspace, and the epicshop app.
  #
  # The workshop's own "setup" script is deliberately not run. It execs
  # `epicshop setup`, whose only build-related job is another `pkgmgr install`
  # that this install has already done — and reaching it requires PKGMGR=npm,
  # which that nested install would inherit and use to npm-install over the
  # pnpm tree. Playground provisioning happens in the workshop app at runtime.
  echo "Installing dependencies with pnpm..."
  pnpm install || return 1

  # Never claim completion the install did not achieve.
  _epic_report_custom_setup . || return 1

  echo "Setup complete. Run: workshop start"
}

# ── workshop start ───────────────────────────────────────────────────────────

_workshop_start() {
  if ! _epic_is_workshop .; then
    echo "Error: this is not an Epic Web workshop (no \"epicshop\" key in package.json)" >&2
    return 1
  fi

  if ! _epic_is_configured .; then
    echo "Workshop setup required. Run: workshop setup" >&2
    return 1
  fi

  if [[ ! -d "./node_modules" || ! -d "./epicshop/node_modules" ]]; then
    echo "Workshop setup required. Run: workshop setup" >&2
    return 1
  fi

  _epic_start_with_npm_routing start "$@"
}

# ── workshop status ──────────────────────────────────────────────────────────

_workshop_status() {
  if ! _epic_is_workshop .; then
    echo "Not an Epic Web workshop (no \"epicshop\" key in package.json)."
    return 1
  fi

  echo "Epic Web workshop: $PWD"

  local root_ws="absent" nested_ws="absent" boundary="no"
  [[ -f ./pnpm-workspace.yaml ]] && root_ws="present"
  [[ -f ./epicshop/pnpm-workspace.yaml ]] && nested_ws="present"
  # Single source of truth for what "boundary established" means.
  _epic_is_configured . && boundary="yes"

  echo "  pnpm-workspace.yaml:          $root_ws"
  echo "  epicshop/pnpm-workspace.yaml: $nested_ws"
  echo "  recursion boundary:           $boundary"

  local root_layout epicshop_layout
  root_layout=$(_epic_layout ./node_modules)
  epicshop_layout=$(_epic_layout ./epicshop/node_modules)
  echo "  node_modules (root):          $root_layout"
  echo "  node_modules (epicshop):      $epicshop_layout"

  local excluded="no"
  if _epic_is_excluded . pnpm-workspace.yaml \
    && _epic_is_excluded . epicshop/pnpm-workspace.yaml; then
    excluded="yes"
  fi
  echo "  locally git-excluded:         $excluded"

  local custom_state
  custom_state=$(_epic_custom_setup_state .)
  custom_state="${custom_state%% *}"
  echo "  setup beyond install:         $custom_state"
  echo ""

  if [[ "$root_layout" == "mixed" || "$epicshop_layout" == "mixed" ]]; then
    echo "Mixed npm/pnpm dependency layout detected."
    echo "Cleanup is required before setup."
    return 1
  fi

  if ! _epic_is_configured . || [[ "$root_layout" == "missing" || "$epicshop_layout" == "missing" ]]; then
    echo "Workshop is not configured."
    echo "Next: workshop setup"
    return 1
  fi

  case "$custom_state" in
    pending)
      echo "Workshop is configured, but required setup work has not been run."
      echo "Next: SKIP_PLAYWRIGHT=1 pnpm run setup:custom"
      return 1
      ;;
    unknown)
      echo "Workshop is configured, but its setup script is unrecognised."
      echo "Next: inspect package.json scripts and complete setup manually"
      return 1
      ;;
  esac

  echo "Workshop is configured and ready."
  echo "Next: workshop start"
}

# ── directory detection (read-only) ──────────────────────────────────────────

# Reports state and names the next command. Writes nothing: no .workshop.env,
# no .gitignore edit, no workspace generation, no install, no node install.
#
# An earlier version created files and ran setup-pnpm-workspace here, so merely
# cd-ing into a workshop mutated the repository and produced the malformed
# pnpm-workspace.yaml that caused recursive installs.
epic-detect() {
  _epic_shell_is_interactive || return 0

  if ! _epic_is_workshop .; then
    return 0
  fi

  # Announce once per directory so ordinary navigation stays quiet.
  if [[ "${_EPIC_DETECT_DIR:-}" == "$PWD" ]]; then
    return 0
  fi
  export _EPIC_DETECT_DIR="$PWD"

  if _epic_is_configured . && [[ -d ./node_modules && -d ./epicshop/node_modules ]]; then
    echo "Epic Web workshop ready. Run: workshop start"
  else
    echo "Epic Web workshop detected."
    echo "Workshop setup required. Run: workshop setup"
  fi
}

_detect_npm_project() {
  _epic_shell_is_interactive || return 0

  # Only fire once per directory
  [[ "${_NPM_DETECT_DIR:-}" == "$PWD" ]] && return 0
  export _NPM_DETECT_DIR="$PWD"

  # Must have package.json
  [[ -f "./package.json" ]] || return 0

  # Skip if pnpm-lock.yaml already exists — already migrated
  [[ -f "./pnpm-lock.yaml" ]] && return 0

  # Skip Epic Web projects — epic-detect handles those
  _epic_is_workshop . && return 0

  # Only flag if package-lock.json exists (confirms npm is managing this)
  [[ -f "./package-lock.json" ]] || return 0

  echo ""
  echo "npm project detected (package-lock.json found, no pnpm-lock.yaml)."
  echo "   To migrate to pnpm:"
  echo "     pnpm import          # convert package-lock.json -> pnpm-lock.yaml"
  echo "     rm package-lock.json # remove the npm lockfile"
  echo "     pnpm install         # verify everything resolves"
  echo ""
}

# ── clone-and-set-up helper ──────────────────────────────────────────────────

epic-start() {
  local repo_url="$1"
  local dir_name="$2"

  if [[ -z "$repo_url" ]]; then
    echo "Usage: epic-start <repository-url> [directory-name]" >&2
    echo "Example: epic-start https://github.com/epicweb-dev/full-stack-foundations.git" >&2
    return 1
  fi

  if [[ -z "$dir_name" ]]; then
    dir_name=$(basename "$repo_url" .git)
    echo "No directory name specified, using: $dir_name"
  fi

  echo "Cloning repository..."
  git clone --depth 1 "$repo_url" "$dir_name" || return 1

  cd "$dir_name" || return 1

  echo "Detecting required Node.js version..."
  ensure-node "" "./package.json"

  workshop setup
}

# Only perform zsh-specific setup when running under zsh. bats sources this
# module under bash, where add-zsh-hook does not exist.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd epic-detect
  add-zsh-hook chpwd _detect_npm_project
  epic-detect
  _detect_npm_project
fi
