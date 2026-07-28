# Product Roadmap

## Purpose and authority

[`PRODUCT.md`](./PRODUCT.md) defines the product and remains the authority for
architectural decisions. This roadmap records the sequence from the current
implementation to a trustworthy first release.

[`CLEAN_MACHINE_ACCEPTANCE.md`](./CLEAN_MACHINE_ACCEPTANCE.md) owns detailed
evidence. [`DECISIONS.md`](./DECISIONS.md) owns accepted architectural
decisions. GitHub issues and pull requests own implementation-level tasks.
This file is intentionally not a changelog or a list of every possible feature.

## Status key

- **Complete** — implemented and supported by the stated evidence.
- **Active** — cross-cutting work that continues alongside the current phase.
- **Next** — the current product phase.
- **Queued** — approved direction, waiting on an earlier dependency.
- **Release gate** — evidence required before calling the product ready.
- **Deferred** — explicitly outside the first release.

## Current position

### Foundation — Complete

The project now has:

- a public framework with no user's identity or application choices;
- a private, user-owned flake that pins the framework revision;
- readable modular templates for hosts, applications, macOS settings, and home
  configuration;
- upstream-first installation without requiring a framework fork;
- separate create-new and restore-existing installer journeys;
- a profile-owned `./bootstrap` that uses the one framework restore engine;
- non-destructive restore preflight and separately confirmed activation;
- profile-aware application management with legacy compatibility;
- beginner package discovery and App Store Copy Link support;
- profile-local Git identity when no global identity exists;
- automated two-machine creation, backup, and restore contract tests.

These foundations do not yet prove the complete clean-Mac, no-AI journey.

### Test-suite integrity — Active

**Outcome:** Automated checks communicate truthful results and protect supported
behavior without making test count a proxy for product quality.

The recorded inventory, integrity findings, and ordered cleanup work live in
[`TEST_SUITE_AUDIT.md`](./TEST_SUITE_AUDIT.md).

Done when:

- every suite has one documented responsibility;
- tests exercise production behavior rather than recreated copies;
- publication and destructive failures cannot produce misleading success;
- Nix ownership and safety claims use resolved evaluation where practical;
- duplicated cases are consolidated without losing boundary coverage;
- compatibility tests have explicit retirement conditions tied to their
  supported feature;
- the clean-machine release gate remains independent of automated test count.

## Path to v1

### Phase 1 — Truthful public onboarding — Complete

**Outcome:** A first-time visitor sees the current product rather than the old
fork-first and `.local/settings.nix` architecture.

Done when:

- `README.md` explains the public framework and private profile accurately;
- the canonical command is `setup.sh` with create and restore journeys;
- ordinary users are not told to fork the framework;
- application, backup, restore, update, and ownership guidance link to one
  current source each;
- obsolete entry points and documents are either redirected, clearly marked as
  legacy, or removed through a compatibility-reviewed change;
- documentation examples agree with executable help and tests.

### Phase 2 — Private-profile backup journey — Complete

**Outcome:** A user can turn a local private profile into a real recovery
artifact without the framework assuming a Git hosting provider.

Done when:

- public documentation explains that a local Git repository is not a backup;
- a provider-neutral walkthrough covers creating a private remote, pushing, and
  verifying the upstream state;
- GitHub may be shown as an example but is not required by the architecture;
- secret scanning and the limits of Git backup are explicit;
- a restore rehearsal proves the documented remote can recover the profile.

Automatic remote creation is not required for v1.

### Phase 3 — Explicit new-host restore — Complete

**Outcome:** Restoring on a Mac whose hostname is absent from the profile is
safe and understandable.

Done when:

- restore offers only three explicit choices: add a reviewed host, rename the
  Mac to an existing host, or stop;
- adding a host shows the generated file and native Nix/Git operations;
- no existing host, framework input, or lock file is silently replaced;
- preflight remains the default and activation remains separately confirmed;
- tests cover known hosts, new hosts, cancellation, and lock preservation.

### Phase 4 — Existing-profile migration — Next

**Outcome:** Existing users can reach the readable modular layout without an
automatic rewrite or a second source of truth.

Current evidence and the responsibility-by-responsibility procedure are
documented in
[`PRIVATE_PROFILE_MIGRATION.md`](./PRIVATE_PROFILE_MIGRATION.md).

Done when:

- a preview-only inventory identifies active legacy files by evidence;
- migration happens on a private branch, one responsibility at a time;
- applications, macOS preferences, Home Manager options, adopted files, and
  identity retain equivalent resolved values;
- AI editor links move from the legacy `.local` flag to a readable modular
  Home Manager option while retaining the legacy flag as a compatibility
  fallback;
- every category is evaluated before the next category moves;
- the live host switches only after a reviewed build succeeds;
- legacy support remains intact for profiles that have not migrated.

Removing the `.local` bridge is not authorized by merely starting this phase.
It requires completed migration evidence and a separate compatibility decision.

### Phase 5 — Physical and no-AI acceptance — Release gate

**Outcome:** The product claim is demonstrated by people and hardware, not
inferred from green tests.

Done when:

- Mac A starts clean, installs prerequisites, creates a profile, selects apps,
  connects a private backup, and activates successfully;
- Mac B restores that profile through the public installer and through the
  profile-owned bootstrap;
- the new-host path, framework pin, lock preservation, Homebrew installation,
  Home Manager activation, and managed files are verified;
- a first-time user completes the documented journey without AI or undocumented
  help;
- public evidence records versions, prompts, and failures without private data.

### Phase 6 — v1 release readiness — Release gate

**Outcome:** The supported product has a clear boundary and a reproducible
release.

Done when:

- every definition-of-success item in `PRODUCT.md` has linked evidence;
- `dot validate` and macOS flake evaluation pass on the release commit;
- supported hardware, macOS scope, backup limits, and legacy status are stated;
- documentation contains no known promise the implementation does not fulfil;
- the release notes distinguish current behavior, compatibility paths, and
  deferred work;
- a versioned release is created only after the clean-machine gate passes.

## Deferred beyond v1

- Linux support.
- A graphical configuration application.
- A curated or duplicated application catalog.
- Copying the complete framework into every private profile.
- Automatic private-remote creation across hosting providers.
- Community presets that introduce opinionated applications or settings.
- Removal of legacy compatibility before migration evidence permits it.

## How roadmap work proceeds

- Work moves in the smallest independently reviewable and testable changes.
- Approval of this roadmap is standing direction for the phases above.
- New scope, contradictory evidence, destructive migration, live activation,
  private-data publication, or a changed safety boundary requires a new
  decision before proceeding.
- A phase is marked complete only when its stated evidence exists.
- Roadmap changes should replace stale claims rather than accumulate parallel
  plans.
