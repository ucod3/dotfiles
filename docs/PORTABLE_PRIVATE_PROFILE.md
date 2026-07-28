# Portable Private Profile Contract

## Status

Design target only. This document does not change the installer, bootstrap,
rebuild path, public modules, or any existing `~/dotfiles-private` repository.

The product contract in [`PRODUCT.md`](./PRODUCT.md) remains authoritative. This
document defines what it means for a private profile to be portable and able to
restore itself without making the user permanently dependent on
`ucod3/dotfiles` as an installation website or command entry point.

## Product statement

`dotfiles-private` is a complete, portable, user-owned definition of a Mac. It
contains all of the owner's choices and records the exact framework revision
used to apply them.

It is **self-contained in capability**, not necessarily self-contained in source
code.

The profile owns:

- host definitions
- application choices
- macOS preferences
- Home Manager configuration
- adopted files
- user identity
- the framework input
- the exact framework revision in `flake.lock`
- a stable restore entry point

The reusable framework owns:

- nix-darwin and Home Manager composition machinery
- safe package and Homebrew integration
- validation and destructive-operation guardrails
- rebuild and restore implementation
- thin convenience commands

A normal profile references and pins that framework rather than copying all of
its implementation into the private repository.

## Three distinct repositories and roles

The product must not conflate these roles.

### Public framework

Typically `ucod3/dotfiles`.

It provides reusable implementation, templates, public documentation, and an
optional discovery installer. An advanced user may instead maintain a compatible
framework fork.

### Private profile

For example `alice/dotfiles-private`.

It is the user's recovery artifact and source of truth. It decides which
framework to use through `flake.nix`, and `flake.lock` records the exact revision.
It may be hosted on GitHub, GitLab, another Git remote, or only exist locally
until the owner chooses to publish it.

### Framework fork

For example `alice/dotfiles`.

This is optional. It exists only when the user intentionally maintains different
framework behavior. It is not where personal application choices or adopted
files need to live.

## Core restore principle

There is one restore contract with two entrances:

```text
Public installer
    -> creates or clones the private profile
    -> invokes the profile restore contract

Private-profile bootstrap
    -> invokes the same profile restore contract
```

The public installer is a convenience and discovery path. It must not be the
only way to recover a machine.

A user who already owns a private profile must eventually be able to perform a
journey conceptually equivalent to:

```bash
git clone <private-profile-repository> ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap
```

After Nix is available, the stable native entry point should be conceptually:

```bash
nix run .#restore
```

The exact command shape may change during implementation, but both entrances
must converge on the same restore engine.

## Framework selection and pinning

A new profile uses the upstream framework by default:

```nix
inputs.dotfiles.url = "github:ucod3/dotfiles";
```

An advanced profile may use another compatible source:

```nix
inputs.dotfiles.url = "github:alice/dotfiles";
```

or another Nix-supported flake reference.

`flake.lock` records the exact revision. Restoring a profile must use that
existing input and lock. Restore must not silently replace the framework source,
update the lock, or repin the profile to the installer it happened to come from.

The public installer therefore stops making framework decisions after it has
cloned an existing profile.

## User journeys

### Journey A — create a new local profile

The beginner path may start from the public installer:

```text
Create a new profile
```

The flow:

1. install prerequisites
2. generate a readable private profile
3. default its framework input to `github:ucod3/dotfiles`
4. initialize a normal local Git repository
5. collect application and preference choices into the private profile
6. create the current host definition
7. build and activate through the profile restore contract
8. explain that the profile is not backed up until it has a remote

No GitHub account or private remote is required to complete initial setup.
Choosing not to create a remote is an opt-out from publication, not an opt-out
from having a private source of truth.

### Journey B — restore through the public installer

A user may return to the public project and supply an existing private profile:

```text
Restore an existing profile
Private profile repository: <clone URL>
```

The flow:

1. install prerequisites
2. clone the private profile
3. preserve its `flake.nix` and `flake.lock`
4. invoke the profile's restore contract
5. build the matching host, or deliberately add a new host

The installer must not rerun the application questionnaire, regenerate existing
configuration, or replace the framework input.

### Journey C — restore directly from the private profile

A user who already knows their private repository should not need to revisit the
public repository:

```bash
git clone <private-profile-repository> ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap
```

This path invokes the same restore engine as Journey B. It is documented as the
owner-controlled recovery path, while the public installer remains the easiest
path for discovery and first-time users.

### Journey D — use a custom framework

A new advanced profile may be created with an explicit framework input. An
existing profile already records that choice.

Restoration never asks the user to choose between upstream and a fork unless the
profile itself is incomplete or invalid.

## Proposed generated profile surface

A newly generated profile should eventually include:

```text
~/dotfiles-private/
├── README.md
├── bootstrap
├── flake.nix
├── flake.lock
├── identity.nix
├── hosts/
├── apps/
├── macos/
└── home/
```

### `bootstrap`

A small, inspectable shell entry point owned by the private profile.

It should do only the minimum needed before Nix can take over:

- verify macOS and supported architecture
- ensure required command-line tools are available
- install or hand off to the documented Nix prerequisite when missing
- invoke the profile's native restore application
- print the native command it runs

It must not contain a second implementation of restore behavior, application
selection, host composition, or framework updates.

### `flake.nix`

In addition to normal `darwinConfigurations`, the private flake should expose a
stable restore application by reusing the framework input it already pins.
Conceptually:

```nix
apps.aarch64-darwin.restore =
  inputs.dotfiles.lib.mkRestoreApp {
    profile = self;
  };
```

This is illustrative, not a final API. The implementation must remain ordinary
Nix and avoid a proprietary profile schema.

### `README.md`

The generated README must document both recovery entrances:

1. public installer plus private repository URL
2. direct clone plus `./bootstrap`

It must also explain that:

- the profile contains the user's choices
- the framework input supplies reusable implementation
- `flake.lock` pins the exact implementation revision
- changing the framework is an explicit edit/update
- a local Git repository is not a backup

## Host behavior during restore

Restore must be explicit about machine identity.

### Existing hostname

When `hosts/<current-hostname>.nix` exists, restore builds that host without
rewriting it.

### New hostname

When the current hostname is absent, restore must not silently select another
host or overwrite an existing host file.

The user should receive a clear choice to:

- add a new host based on a reviewed template
- rename the machine to match an existing host
- stop and inspect the profile

Adding a host is a deliberate profile mutation. The command must show the file
created, stage it when required by Nix evaluation, and leave committing and
publishing visible to the owner.

## Safety boundaries

Restore must:

- refuse to overwrite a non-empty destination
- preserve the existing `flake.nix` and `flake.lock`
- avoid updating any input unless explicitly requested
- avoid rerunning new-profile questionnaires
- avoid deleting applications or configuration as a side effect of discovery
- avoid publishing the private profile automatically
- avoid choosing another host silently
- stop on an invalid or incomplete profile with actionable diagnostics
- show which repository, host, lock file, and framework revision will be used
- support dry evaluation or build before activation where practical

The public installer must never make ownership decisions on behalf of an
existing profile.

## Existing-profile compatibility

Existing profiles will not immediately contain `bootstrap` or a restore flake
application.

Compatibility should be staged:

1. the public installer recognizes existing legacy and modular profiles
2. the public framework can invoke the current bootstrap/rebuild path for those
   profiles without rewriting them
3. newly generated profiles receive the self-restore entry points
4. an optional, reviewed migration may add the entry points to an existing
   private profile later

Absence of `bootstrap` must not be interpreted as permission to regenerate the
profile.

## One restore engine

The following would be an architectural failure:

- one restore implementation in `install.sh`
- another implementation copied into every private profile
- a third implementation hidden in a convenience command

The intended ownership is:

```text
private bootstrap: prerequisite handoff only
private flake: selects and pins framework; exposes restore application
public framework: implements restore behavior
public installer: creates/clones profile, then invokes profile contract
```

This keeps restore behavior updateable and testable without making the profile
dependent on a particular public web entry point.

## Non-goals

### Literal framework copy in every private repository

Vendoring the entire public framework would duplicate code, blur ownership,
complicate updates, and prevent fixes from flowing through a normal pinned-input
update. It may be explored later as an archival/export feature, but it is not
the ordinary model.

### Profile-free operation

A user may decline to publish their profile, but the system still needs a
readable source of truth for choices and recovery. Hidden machine-local state is
not the normal product path.

### GitHub-only profiles

The contract is Git-based and Nix-based, not GitHub-specific. Authentication and
remote hosting remain the user's choice.

### Automatic migration of live profiles

No restore feature grants permission to reorganize or rewrite an existing
private repository.

## Acceptance tests

Implementation is not complete until these journeys pass without AI assistance:

1. create a new profile with no GitHub account and rebuild successfully
2. add a private remote later without restructuring the profile
3. restore an upstream-based profile through the public installer
4. restore the same profile by cloning it directly and running its bootstrap
5. restore a profile pinned to a framework fork without replacing that input
6. restore using the committed `flake.lock` without silently updating it
7. restore an existing hostname without changing tracked profile files
8. handle a new hostname through an explicit, reviewable host-addition path
9. refuse a non-empty destination without data loss
10. prove legacy profiles continue to use their current path unchanged

## Implementation sequence

### Phase 1 — framework restore contract

- define the stable framework-side restore entry point
- make repository, profile, host, and lock selection visible
- add fixture tests without activating a live machine

### Phase 2 — generated self-restore entry points

- add the small `bootstrap` file to new-profile templates
- expose the private flake restore application
- document direct restoration in generated `README.md`

### Phase 3 — public installer modes

- replace fork-first public-repository selection with `new` and `restore` modes
- make `new` generate a local private profile
- make `restore` clone a supplied private profile
- have both modes invoke the same profile restore contract

### Phase 4 — compatibility and clean-machine proof

- retain legacy profile support without rewriting profiles
- exercise upstream and custom-framework inputs
- perform clean-machine creation and restoration tests
- update the root README only after the actual journeys match the documentation

## Decision checkpoint

No installer rewrite should begin until this contract is reviewed. In
particular, implementation must not make `ucod3/dotfiles/install.sh` the only
recovery path, copy restore machinery into every private repository, or mutate an
existing profile merely because it lacks the new entry points.
