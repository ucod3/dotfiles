# Testing

Three layers, cheapest first. Run all of them with `dot validate`.

## `dot validate`

The single entry point. Checks, in order:

1. **Zsh syntax** — `zsh -n` on every module, `custom.zsh`, `.zshenv`
2. **Bash syntax** — `bash -n` on every tracked bash script
3. **Shell lint** — `shellcheck` (warnings do not fail the run)
4. **Nix syntax** — `nix-instantiate --parse` on every tracked `.nix` file
5. **Nix flake check** — full evaluation (see below). **Hard failure.**
6. **Unit tests** — the bats suite. **Hard failure.**
7. **Common mistakes** — deprecated APIs, hardcoded paths, `builtins.getEnv`
   scope, staged-secret heuristics
8. **Git tracking** — files Nix references, and agent config, must be tracked

```bash
dot validate           # everything (a few minutes)
dot validate --quick   # skip the slow Nix evaluation
```

Exit code is non-zero only on **errors**; warnings still pass. A failing bats
suite is an error. It used to be a warning, so `validate` exited 0 against a red
suite and everything built on it — the fail-closed pre-commit hook, `dot update`'s
pre-flight, `dot apps`' post-mutation check — inherited that false pass.

The file lists are derived from `git ls-files`, not hand-maintained — a
previous pair of hand-written lists here and in CI had drifted apart and left
several scripts checked by neither.

## `nix flake check`

`darwinConfigurations` is empty in this repo on purpose, which would normally
make `nix flake check` a no-op that validates nothing. Three checks close that
gap by instantiating the modules against a dummy host:

| Check | Asserts |
|---|---|
| `cold` | Framework defaults only — a fresh public fork with no `.local/`. Guards the "installs nothing opinionated" and graceful-degradation contracts. |
| `full` | Every app set and home module enabled. Every cask name typed, every `nixPackages` attribute resolvable in nixpkgs. |
| `cold-is-nondestructive` | A cold fork resolves `homebrew.onActivation.cleanup` to `"none"` and `macosDefaults` to `false`. Pins ADR-007. |

```bash
nix flake check
```

These evaluate the module tree without building a macOS system.

### Verifying the destructive-default guard by hand

The `cold-is-nondestructive` check proves the safe path. To prove the assertion
that blocks the unsafe one actually fires:

```bash
nix eval --impure --expr '
let
  f = builtins.getFlake "git+file:///Users/'"$USER"'/dotfiles";
  lib = f.inputs.nixpkgs.lib;
in (f.inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  specialArgs = { self = f; user = "t"; inputs = f.inputs; };
  modules = [
    f.darwinModules.coreSystem
    { dotfiles.homebrew.cleanup = "uninstall"; homebrew.casks = lib.mkForce []; }
  ];
}).config.system.build.toplevel.drvPath'
```

This must **fail** with "the declared cask list is EMPTY". Note the
`git+file://` URL: a bare path uses the `path:` scheme, which copies `.git/`
into the store and hard-fails on the `core.fsmonitor` socket (ADR-004).

## Unit tests (bats)

```bash
bats tests/           # all
bats tests/test_cold_clone.bats
```

| Suite | Covers |
|---|---|
| `test_cold_clone.bats` | First-run behaviours that only misbehave on a machine lacking this repo's tooling: brew-absent exit codes, `NIX_CONFIG` flake enabling, the `darwin-rebuild` fallback, gitleaks without Homebrew, settings-layer detection |
| `test_lib_node.bats` | `lib/node.sh` node resolution, plus a regression assert that the error text names the current pnpm API |
| `test_node_version.bats` | `detect-node-version` semver handling |
| `test_rebuild.bats` | ADR-009: the pin is never auto-bumped, `--override-local` semantics, flag parsing |
| `test_dot_adopt.bats` | The adoption guards — every one is the difference between a refusal and damage to a live `$HOME` |
| `test_adoptability.bats` | ADR-010/011: fork ownership, host-plural private flakes, `dot apps` reading `.local/`, `promote`'s ordering and refusals, and that a cold-fork shell redefines nothing |

`tests/bats_helper.bash` provides `assert_success`, `assert_failure`,
`assert_output`, `assert_output_contains`, `make_temp`, `cleanup_temp`. Load it
with `load 'bats_helper'` in `setup()`.

Install bats if needed: `nix shell nixpkgs#bats`.

## CI

`.github/workflows/ci.yml` runs two jobs:

- **lint** (Ubuntu) — bash/zsh syntax, shellcheck, Nix parse, gitleaks over the
  full history, bats.
- **eval** (macOS) — `nix flake check`. It needs macOS because the checks
  instantiate darwin modules; without this job the evaluation checks above never
  ran in CI at all.

Two suites depend on the environment rather than the code, and fail locally in
containers that CI does not reproduce: `check-brew-manual-installers exits 0 when
brew is absent` refuses to run as root, and `--override-local rejects a path that
is not a git repository` needs `nix` on `PATH` (`require_nix` runs before flag
parsing). Both pass on the CI runner and on a Mac.

The runner has no `.local/`, so the eval job exercises the cold-fork path by
construction.

## Testing `install.sh`

`install.sh` modifies the machine it runs on. Test it in a VM or a throwaway
user account, never on your working system.

It accepts `-v/--verbose` and `-h/--help`. There is **no** `--dry-run`; unknown
options exit 1.

```bash
# Throwaway account (safer than it sounds — a fresh home directory)
sudo dscl . -create /Users/coldtest
sudo dscl . -create /Users/coldtest UserShell /bin/zsh
sudo dscl . -create /Users/coldtest NFSHomeDirectory /Users/coldtest
sudo createhomedir -c -u coldtest
su - coldtest
```

Then run the installer and confirm: prompts appear (not consumed by the script),
the build completes, `git commit` works afterward, and no cask on the machine is
uninstalled.

## Before you commit

The pre-commit hook already runs `dot validate --quick` plus gitleaks and fails
closed. For anything touching Nix evaluation, run the full `dot validate` too —
`--quick` skips exactly the checks that catch module breakage.
