#!/usr/bin/env bats
#
# Epic Web workshop pnpm compatibility.
#
# Covers the three guarantees the workshop commands are supposed to make:
#   - directory detection never writes or installs
#   - setup generates both workspace files, idempotently, from parsed JSON
#   - start only starts, and routes through PKGMGR=npm so pkgmgrx uses npx
#
# Run with: bats tests/test_workshop_pnpm.bats

setup() {
  load 'bats_helper'
  load '../config/zsh/modules/npm-compat.zsh'
  load '../config/zsh/modules/workshop.zsh'

  WORK="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/ws"
  rm -rf "$WORK"
  mkdir -p "$WORK"

  CALL_LOG="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/calls.log"
  : > "$CALL_LOG"
}

# A minimal Epic Web workshop: the "epicshop" key, npm workspaces, an epicshop
# sub-package, and a git repo so .git/info/exclude is reachable.
make_workshop() {
  local dir="$WORK"
  mkdir -p "$dir/epicshop"
  cat > "$dir/package.json" <<'EOF'
{
  "name": "web-auth",
  "private": true,
  "epicshop": { "title": "Test Workshop" },
  "scripts": { "postinstall": "cd ./epicshop && pkgmgr install" },
  "workspaces": ["exercises/*/*", "examples/*"]
}
EOF
  echo '{"name":"epicshop-deps"}' > "$dir/epicshop/package.json"
  git -C "$dir" init -q 2>/dev/null
  echo "$dir"
}

# Record any package-manager invocation instead of running one.
stub_package_managers() {
  pnpm() { echo "PKGMGR=${PKGMGR:-unset} pnpm $*" >> "$CALL_LOG"; return 0; }
  real-npm() { echo "real-npm $*" >> "$CALL_LOG"; return 0; }
  workshop-npx() { echo "workshop-npx $*" >> "$CALL_LOG"; return 0; }
}

# Fingerprint every path and its contents, for "this wrote nothing" assertions.
tree_fingerprint() {
  ( cd "$1" && find . -not -path './.git/*' | LC_ALL=C sort | while IFS= read -r p; do
      if [ -f "$p" ]; then printf '%s %s\n' "$p" "$(cksum < "$p")"; else printf '%s\n' "$p"; fi
    done )
}

require_node() {
  command -v node >/dev/null 2>&1 || skip "node not available"
}

# ── 1/2. workspace parsing ───────────────────────────────────────────────────

@test "workspace patterns are parsed from JSON, not scraped" {
  require_node
  local dir; dir=$(make_workshop)

  run _epic_workspace_patterns "$dir/package.json"
  assert_success
  [ "${lines[0]}" = "exercises/*/*" ]
  [ "${lines[1]}" = "examples/*" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "the literal key 'workspaces' is never emitted as a pattern" {
  require_node
  local dir; dir=$(make_workshop)

  run _epic_workspace_patterns "$dir/package.json"
  assert_success
  # The grep-based predecessor emitted `workspaces` here, and pnpm then treated
  # it as a workspace glob.
  for line in "${lines[@]}"; do
    [ "$line" != "workspaces" ]
  done
}

@test "object form of workspaces is supported" {
  require_node
  local dir="$WORK"; mkdir -p "$dir"
  echo '{"workspaces":{"packages":["packages/*"]}}' > "$dir/package.json"

  run _epic_workspace_patterns "$dir/package.json"
  assert_success
  assert_output "packages/*"
}

@test "a missing or unsupported workspaces field fails loudly" {
  require_node
  local dir="$WORK"; mkdir -p "$dir"
  echo '{"name":"no-workspaces"}' > "$dir/package.json"

  run _epic_workspace_patterns "$dir/package.json"
  assert_failure

  echo '{"workspaces":"exercises/*"}' > "$dir/package.json"
  run _epic_workspace_patterns "$dir/package.json"
  assert_failure
}

# ── 3/4. generated files ─────────────────────────────────────────────────────

@test "setup-pnpm-workspace writes the root workspace with real globs" {
  require_node
  local dir; dir=$(make_workshop)

  run setup-pnpm-workspace "$dir"
  assert_success
  [ -f "$dir/pnpm-workspace.yaml" ]

  grep -q "exercises/\*/\*" "$dir/pnpm-workspace.yaml"
  grep -q "examples/\*" "$dir/pnpm-workspace.yaml"
  grep -q "^nodeLinker: hoisted$" "$dir/pnpm-workspace.yaml"
  # pnpm 11 spells this allowBuilds and takes a map. The pnpm 10 spelling
  # onlyBuiltDependencies parses but is inert: pnpm still reports
  # ERR_PNPM_IGNORED_BUILDS and exits 1, which failed the fixture install.
  grep -q "^allowBuilds:$" "$dir/pnpm-workspace.yaml"
  grep -q "^  'esbuild': true$" "$dir/pnpm-workspace.yaml"
  ! grep -q "onlyBuiltDependencies" "$dir/pnpm-workspace.yaml"
  # Build permission stays an explicit list, never a blanket allow.
  ! grep -q "dangerouslyAllowAllBuilds" "$dir/pnpm-workspace.yaml"
}

@test "setup-pnpm-workspace writes the epicshop recursion guard" {
  require_node
  local dir; dir=$(make_workshop)

  run setup-pnpm-workspace "$dir"
  assert_success
  [ -f "$dir/epicshop/pnpm-workspace.yaml" ]
  grep -q "^packages: \[\]$" "$dir/epicshop/pnpm-workspace.yaml"
}

@test "the nested guard satisfies the configured check" {
  require_node
  local dir; dir=$(make_workshop)

  run _epic_is_configured "$dir"
  assert_failure

  setup-pnpm-workspace "$dir" >/dev/null
  run _epic_is_configured "$dir"
  assert_success
}

# ── 5/6. idempotence ─────────────────────────────────────────────────────────

@test "re-running setup-pnpm-workspace produces identical files" {
  require_node
  local dir; dir=$(make_workshop)

  setup-pnpm-workspace "$dir" >/dev/null
  local first; first=$(tree_fingerprint "$dir")

  setup-pnpm-workspace "$dir" >/dev/null
  local second; second=$(tree_fingerprint "$dir")

  [ "$first" = "$second" ]
}

@test "git exclude registration does not duplicate entries" {
  require_node
  local dir; dir=$(make_workshop)

  setup-pnpm-workspace "$dir" >/dev/null
  setup-pnpm-workspace "$dir" >/dev/null
  setup-pnpm-workspace "$dir" >/dev/null

  local count
  count=$(grep -cxF "pnpm-workspace.yaml" "$dir/.git/info/exclude")
  [ "$count" -eq 1 ]

  count=$(grep -cxF "epicshop/pnpm-workspace.yaml" "$dir/.git/info/exclude")
  [ "$count" -eq 1 ]
}

@test "exclude registration is correct under zsh, not just bash" {
  require_node
  command -v zsh >/dev/null 2>&1 || skip "zsh not available"
  local dir; dir=$(make_workshop)

  # zsh does not word-split unquoted parameters. An earlier version passed an
  # accumulated "a b" string to _epic_git_exclude, which bash split into two
  # arguments (tests green) while zsh passed one, writing a single malformed
  # line. This runs the real shell to close that gap.
  zsh -c "
    source '$BATS_TEST_DIRNAME/../config/zsh/modules/npm-compat.zsh'
    setup-pnpm-workspace '$dir' >/dev/null
  "

  [ "$(grep -cxF 'pnpm-workspace.yaml' "$dir/.git/info/exclude")" -eq 1 ]
  [ "$(grep -cxF 'epicshop/pnpm-workspace.yaml' "$dir/.git/info/exclude")" -eq 1 ]
  # No line containing both paths.
  ! grep -q 'pnpm-workspace.yaml epicshop/' "$dir/.git/info/exclude"
}

@test "the tracked .gitignore is never modified" {
  require_node
  local dir; dir=$(make_workshop)
  echo "node_modules" > "$dir/.gitignore"
  local before; before=$(cksum < "$dir/.gitignore")

  setup-pnpm-workspace "$dir" >/dev/null

  [ "$(cksum < "$dir/.gitignore")" = "$before" ]
}

# ── 7/8. directory detection is read-only ────────────────────────────────────

@test "epic-detect writes nothing to the workshop" {
  local dir; dir=$(make_workshop)
  _epic_shell_is_interactive() { return 0; }
  stub_package_managers

  cd "$dir"
  local before; before=$(tree_fingerprint "$dir")

  unset _EPIC_DETECT_DIR
  run epic-detect
  assert_success

  [ "$(tree_fingerprint "$dir")" = "$before" ]
  # Specifically: none of the artefacts the old hook created.
  [ ! -f "$dir/.workshop.env" ]
  [ ! -f "$dir/pnpm-workspace.yaml" ]
  [ ! -f "$dir/.gitignore" ]
}

@test "epic-detect runs no package manager" {
  local dir; dir=$(make_workshop)
  _epic_shell_is_interactive() { return 0; }
  stub_package_managers

  cd "$dir"
  unset _EPIC_DETECT_DIR
  run epic-detect
  assert_success

  [ ! -s "$CALL_LOG" ]
}

@test "epic-detect names setup when unconfigured and start when ready" {
  require_node
  local dir; dir=$(make_workshop)
  _epic_shell_is_interactive() { return 0; }
  cd "$dir"

  unset _EPIC_DETECT_DIR
  run epic-detect
  assert_output_contains "Workshop setup required. Run: workshop setup"

  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"

  unset _EPIC_DETECT_DIR
  run epic-detect
  assert_output_contains "Epic Web workshop ready. Run: workshop start"
}

@test "epic-detect announces once per directory" {
  local dir; dir=$(make_workshop)
  _epic_shell_is_interactive() { return 0; }
  cd "$dir"

  unset _EPIC_DETECT_DIR
  epic-detect >/dev/null           # first visit sets the guard
  run epic-detect                  # second visit in the same directory
  assert_success
  assert_output ""
}

# ── 9/10/11. start ───────────────────────────────────────────────────────────

@test "workshop start refuses when setup is incomplete" {
  local dir; dir=$(make_workshop)
  stub_package_managers
  cd "$dir"

  run workshop start
  assert_failure
  assert_output_contains "Workshop setup required. Run: workshop setup"
  [ ! -s "$CALL_LOG" ]
}

@test "workshop start refuses when the recursion guard is missing" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  rm -f "$dir/epicshop/pnpm-workspace.yaml"
  cd "$dir"

  run workshop start
  assert_failure
  assert_output_contains "Workshop setup required. Run: workshop setup"
}

@test "setup installs with PKGMGR unset and never runs the epicshop setup script" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  cd "$dir"

  run workshop setup
  assert_success

  # PKGMGR must NOT leak into the install. `epicshop setup` shells out to
  # `pkgmgr install`, which inherits PKGMGR; with it set to npm that nested
  # call ran a real `npm install` over the pnpm tree and manufactured the very
  # mixed layout this module refuses to install into.
  grep -qxF "PKGMGR=unset pnpm install" "$CALL_LOG"
  ! grep -q "PKGMGR=npm" "$CALL_LOG"
  ! grep -q "run setup" "$CALL_LOG"
  assert_output_contains "Setup complete. Run: workshop start"
}

@test "workshop start routes through PKGMGR=npm pnpm start" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  cd "$dir"

  run workshop start
  assert_success
  grep -qxF "PKGMGR=npm pnpm start" "$CALL_LOG"
}

@test "workshop start installs nothing and writes nothing" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  cd "$dir"

  local before; before=$(tree_fingerprint "$dir")
  run workshop start
  assert_success

  [ "$(tree_fingerprint "$dir")" = "$before" ]
  # start, and only start
  ! grep -q "pnpm install" "$CALL_LOG"
  ! grep -q "run setup" "$CALL_LOG"
}

# ── 12. status is read-only ──────────────────────────────────────────────────

@test "workshop status writes nothing and reports the next command" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  cd "$dir"

  local before; before=$(tree_fingerprint "$dir")
  run workshop status
  assert_failure                    # unconfigured -> non-zero
  assert_output_contains "Workshop is not configured."
  assert_output_contains "Next: workshop setup"
  [ "$(tree_fingerprint "$dir")" = "$before" ]
  [ ! -s "$CALL_LOG" ]

  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  touch "$dir/node_modules/.modules.yaml" "$dir/epicshop/node_modules/.modules.yaml"

  run workshop status
  assert_success
  assert_output_contains "Workshop is configured and ready."
  assert_output_contains "Next: workshop start"
}

# ── setup work the install does not cover ────────────────────────────────────

# Give the fixture the real web-auth setup scripts, plus $1 prisma apps of
# which $2 have a generated client.
add_setup_scripts() {
  local dir="$WORK" apps="$1" generated="$2"
  node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    p.scripts = p.scripts || {};
    p.scripts.setup = "pkgmgrx epicshop setup";
    if (process.argv[2] === "yes") p.scripts["setup:custom"] = "node ./epicshop/setup-custom.js";
    fs.writeFileSync(process.argv[1], JSON.stringify(p, null, 2));
  ' "$dir/package.json" "${3:-yes}"

  local i=0
  while [ "$i" -lt "$apps" ]; do
    mkdir -p "$dir/exercises/0$i.topic/01.problem/prisma"
    touch "$dir/exercises/0$i.topic/01.problem/prisma/schema.prisma"
    if [ "$i" -lt "$generated" ]; then
      mkdir -p "$dir/exercises/0$i.topic/01.problem/node_modules/.prisma/client"
    fi
    i=$((i + 1))
  done
}

@test "a workshop with no setup:custom completes on the install alone" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  # A setup script, but no setup:custom — epicshop setup's only other action is
  # the install, which has just run. Ungenerated prisma apps are irrelevant here
  # because nothing declares work to generate them.
  add_setup_scripts 2 0 no
  cd "$dir"

  run workshop setup
  assert_success
  assert_output_contains "Setup complete. Run: workshop start"
}

@test "an unrecognised setup script stops setup rather than being assumed" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  node -e '
    const fs=require("fs");
    const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
    p.scripts={setup:"./scripts/bespoke-bootstrap.sh --provision"};
    fs.writeFileSync(process.argv[1],JSON.stringify(p,null,2));
  ' "$dir/package.json"
  cd "$dir"

  run workshop setup
  assert_failure
  assert_output_contains "setup script is not one this"
  assert_output_contains "requires manual handling"
  ! [[ "$output" == *"Setup complete"* ]]
}

@test "status moves from pending to ready as prisma clients appear" {
  require_node
  local dir; dir=$(make_workshop)
  add_setup_scripts 3 1         # 3 prisma apps, only 1 generated
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  touch "$dir/node_modules/.modules.yaml" "$dir/epicshop/node_modules/.modules.yaml"
  cd "$dir"

  run workshop status
  assert_failure
  assert_output_contains "setup beyond install:         pending"
  ! [[ "$output" == *"configured and ready"* ]]

  # Generate the remaining two.
  mkdir -p "$dir/exercises/01.topic/01.problem/node_modules/.prisma/client"
  mkdir -p "$dir/exercises/02.topic/01.problem/node_modules/.prisma/client"

  run workshop status
  assert_success
  assert_output_contains "setup beyond install:         satisfied"
  assert_output_contains "Workshop is configured and ready."
}

@test "setup stops and reports manual handling when custom work is pending" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  add_setup_scripts 3 0
  cd "$dir"

  run workshop setup
  assert_failure
  assert_output_contains "setup work the install"
  assert_output_contains "SKIP_PLAYWRIGHT=1 pnpm run setup:custom"
  # It must not claim success it did not achieve.
  ! [[ "$output" == *"Setup complete"* ]]
  # It installed, but never ran the custom script itself.
  grep -qxF "PKGMGR=unset pnpm install" "$CALL_LOG"
  ! grep -q "setup:custom" "$CALL_LOG"
  ! grep -q "PKGMGR=npm" "$CALL_LOG"
}

@test "setup completes when the custom work is already satisfied" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  add_setup_scripts 2 2
  cd "$dir"

  run workshop setup
  assert_success
  assert_output_contains "Setup complete. Run: workshop start"
}

@test "status does not report ready while custom setup is pending" {
  require_node
  local dir; dir=$(make_workshop)
  add_setup_scripts 3 0
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  touch "$dir/node_modules/.modules.yaml" "$dir/epicshop/node_modules/.modules.yaml"
  cd "$dir"

  local before; before=$(tree_fingerprint "$dir")
  run workshop status
  assert_failure
  assert_output_contains "setup beyond install:         pending"
  assert_output_contains "required setup work has not been run"
  assert_output_contains "Next: SKIP_PLAYWRIGHT=1 pnpm run setup:custom"
  ! [[ "$output" == *"configured and ready"* ]]
  # still read-only
  [ "$(tree_fingerprint "$dir")" = "$before" ]
}

@test "status reports ready once custom setup is satisfied" {
  require_node
  local dir; dir=$(make_workshop)
  add_setup_scripts 2 2
  setup-pnpm-workspace "$dir" >/dev/null
  mkdir -p "$dir/node_modules" "$dir/epicshop/node_modules"
  touch "$dir/node_modules/.modules.yaml" "$dir/epicshop/node_modules/.modules.yaml"
  cd "$dir"

  run workshop status
  assert_success
  assert_output_contains "setup beyond install:         satisfied"
  assert_output_contains "Workshop is configured and ready."
}

# ── 13. mixed layouts ────────────────────────────────────────────────────────

@test "a mixed npm/pnpm layout is detected" {
  local dir; dir=$(make_workshop)
  mkdir -p "$dir/node_modules"

  run _epic_layout "$dir/node_modules"
  assert_output "missing"

  touch "$dir/node_modules/.package-lock.json"
  run _epic_layout "$dir/node_modules"
  assert_output "npm"

  touch "$dir/node_modules/.modules.yaml"
  run _epic_layout "$dir/node_modules"
  assert_output "mixed"
}

@test "setup refuses to install over a mixed layout and does not delete it" {
  require_node
  local dir; dir=$(make_workshop)
  stub_package_managers
  mkdir -p "$dir/node_modules"
  touch "$dir/node_modules/.package-lock.json" "$dir/node_modules/.modules.yaml"
  cd "$dir"

  run workshop setup
  assert_failure
  assert_output_contains "Mixed npm/pnpm dependency layout detected."
  assert_output_contains "Cleanup is required before setup."

  # Reported, never performed.
  [ -f "$dir/node_modules/.package-lock.json" ]
  [ -f "$dir/node_modules/.modules.yaml" ]
  [ ! -s "$CALL_LOG" ]
}

@test "status reports a mixed layout" {
  local dir; dir=$(make_workshop)
  mkdir -p "$dir/node_modules"
  touch "$dir/node_modules/.package-lock.json" "$dir/node_modules/.modules.yaml"
  cd "$dir"

  run workshop status
  assert_failure
  assert_output_contains "Mixed npm/pnpm dependency layout detected."
}

# ── 14. non-Epic repositories ────────────────────────────────────────────────

@test "epic-detect is silent and inert outside an Epic Web workshop" {
  local dir="$WORK"; mkdir -p "$dir"
  echo '{"name":"ordinary"}' > "$dir/package.json"
  _epic_shell_is_interactive() { return 0; }
  stub_package_managers
  cd "$dir"

  local before; before=$(tree_fingerprint "$dir")
  unset _EPIC_DETECT_DIR
  run epic-detect
  assert_success
  assert_output ""
  [ "$(tree_fingerprint "$dir")" = "$before" ]
  [ ! -s "$CALL_LOG" ]
}

@test "the npm-project hint still fires for ordinary npm repos" {
  local dir="$WORK"; mkdir -p "$dir"
  echo '{"name":"ordinary"}' > "$dir/package.json"
  echo '{}' > "$dir/package-lock.json"
  _epic_shell_is_interactive() { return 0; }
  cd "$dir"

  unset _NPM_DETECT_DIR
  run _detect_npm_project
  assert_success
  assert_output_contains "npm project detected"
}

# ── 15. existing commands ────────────────────────────────────────────────────

@test "workshop help shows the first-run and everyday workflows" {
  run workshop help
  assert_success
  assert_output_contains "First use:"
  assert_output_contains "workshop setup"
  assert_output_contains "workshop start"
  assert_output_contains "workshop status"
}

@test "workshop npm and npx reach the real binaries" {
  local dir; dir=$(make_workshop)
  stub_package_managers
  cd "$dir"

  run workshop npm --version
  assert_success
  grep -qxF "real-npm --version" "$CALL_LOG"

  run workshop npx --version
  assert_success
  grep -qxF "workshop-npx --version" "$CALL_LOG"
}

@test "an unknown workshop command fails and shows help" {
  local dir; dir=$(make_workshop)
  cd "$dir"

  run workshop bogus
  assert_failure
  assert_output_contains "Unknown command: bogus"
}

# ── real-npm resolution ──────────────────────────────────────────────────────

@test "real-npm resolves npm from PATH, not through pnpm exec" {
  local bindir="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/bin"
  mkdir -p "$bindir"
  printf '#!/bin/sh\necho "real npm: $*"\n' > "$bindir/npm"
  chmod +x "$bindir/npm"

  # If real-npm shelled out to `pnpm exec npm`, this stub would fire instead.
  pnpm() { echo "WRONG: routed through pnpm exec" ; return 0; }

  PATH="$bindir:$PATH" run real-npm --version
  assert_success
  assert_output_contains "real npm: --version"
  ! [[ "$output" == *"WRONG"* ]]
}

@test "real-npm fails with guidance when no npm exists on PATH" {
  local empty="${BATS_TEST_TMPDIR:-${BATS_TMPDIR:-/tmp}}/empty"
  mkdir -p "$empty"

  PATH="$empty" run real-npm --version
  assert_failure
  assert_output_contains "no npm executable found on PATH"
}
