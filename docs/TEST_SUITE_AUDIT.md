# Test Suite Integrity Audit

## Purpose

The suite exists to protect user journeys and safety boundaries, not to produce
a large test count. A test is justified when removing it would leave a
supported outcome, destructive boundary, compatibility promise, or documented
contract unprotected.

This audit was recorded on 2026-07-28 after the suite reached 200 Bats tests.
The product-contract reset began with 110 tests. Since then, 91 tests were
added in new files and one older test was removed, for a net increase of 90.
Implementation is tracked in
[GitHub issue #33](https://github.com/ucod3/dotfiles/issues/33).

No test should be removed merely because it predates the reset. Existing tests
must instead be judged against the current product contract and roadmap.

## Current classification

| Suite | Tests | Current judgment |
| --- | ---: | --- |
| `test_dot_adopt.bats` | 28 | Retain. It exercises destructive file movement, credential refusals, Home Manager collision guards, and backup-risk reporting in sandboxes. |
| `test_restore_profile.bats` | 16 | Retain. Restore behavior and the framework export now use execution and flake-evaluation evidence. |
| `test_setup_installer.bats` | 19 | Retain. Consolidate overlapping flag-validation cases only where failure boundaries remain explicit. |
| `test_profile_aware_apps.bats` | 13 | Retain. It exercises the actual application command and both modular and legacy ownership. |
| `test_clean_machine_acceptance.bats` | 1 | Retain. It is the strongest automated create, publish, and restore contract, while remaining distinct from the physical release gate. |
| `test_migration_preview.bats` | 7 | Retain through Phase 4. Retire or reshape only after migration support reaches its final contract. |
| `test_private_profile_bootstrap.bats` | 4 | Retain. It protects profile-owned recovery and prerequisite boundaries. |
| `test_private_profile_templates.bats` | 10 | Mostly retain. Consolidate generated-document sentence checks separately from structural ownership checks. |
| `test_private_profile_first_run.bats` | 5 | Consolidate with overlapping generator and setup-host coverage. Preserve legacy-host compatibility until its retirement gate. |
| `test_adoptability.bats` | 46 | Split by responsibility. It currently mixes framework-source selection, host generation, path helpers, legacy apps, validation, `promote`, shell neutrality, the legacy installer, and licensing. Several cases duplicate newer suites. |
| `test_cold_clone.bats` | 9 | Preserve the cold-machine contracts. Settings-layer detection now exercises production behavior; remaining source-text assertions still need stronger evidence. |
| `test_rebuild.bats` | 13 | Preserve pin, lock, override, and privilege boundaries. Replace source-shape assertions with command-double behavior where possible. |
| `test_node_version.bats` | 9 | Consolidate repeated semver examples into table-driven coverage. This protects an opt-in web-development workflow rather than the core restore product. |
| `test_lib_node.bats` | 4 | Retain the path-resolution behavior; combine closely related error assertions where useful. |
| `test_public_onboarding_docs.bats` | 11 | Preserve truthful-onboarding coverage, but reduce dependence on exact prose and duplicated sentence assertions. |
| `test_private_profile_backup_docs.bats` | 5 | Preserve the backup safety contract while consolidating exact-text checks. |
| `test_validate.bats` | 2 | Retain. It proves quick validation cannot accidentally perform real Nix evaluation while full validation still does. |

The expected result is a smaller, clearer suite, not a predetermined number.
An initial estimate is roughly 150–170 Bats tests after consolidation, while
retaining or improving the protected behavior. That range is not a target or
release criterion.

## Confirmed integrity problems

### Recreated production logic

Resolved in the first integrity slice: the shared production
`has_settings_layer()` helper now owns shell-side detection, `rebuild` calls it,
and cold-clone tests exercise it with empty, recognized, and obsolete fixture
layouts.

### Misleading success semantics

The `promote` test named “refuses to publish the private flake when gitleaks
finds something” expects the overall command to succeed. The implementation
then continues toward a rebuild and ends with a successful promotion message
plus a warning that the private recovery artifact was not published.

That may be an intentional separation between activation and backup, but the
current command name and exit status can communicate more success than occurred.
This requires a product decision before changing behavior:

- fail the whole command when requested private publication fails;
- split framework activation from private-profile publication; or
- retain advisory success but rename and document the contract so it cannot be
  mistaken for a complete publish.

The test must follow the decided contract rather than silently choosing it.

### Personal-application blacklist

Resolved in the first integrity slice: the personal-name blacklist was removed.
The cold Nix check now asserts that resolved Homebrew formula, cask, and App
Store declarations are empty.

### Source-text assertions

Several rebuild, cold-clone, validation, restore-export, and documentation tests
pass when a particular string exists. These tests may accept dead code and may
fail harmless refactors while missing behavioral regressions.

Source assertions remain appropriate for a small number of static invariants,
such as forbidding a dangerous token anywhere in executable code. Operational
contracts should otherwise use command doubles, generated fixtures, Nix
evaluation, or end-to-end sandbox behavior.

### Duplicate ownership coverage

Framework source selection, profile generation, second-Mac host creation,
modular imports, and adoption wiring are repeated across:

- `test_adoptability.bats`;
- `test_private_profile_first_run.bats`;
- `test_private_profile_templates.bats`;
- `test_setup_installer.bats`;
- `test_clean_machine_acceptance.bats`.

Layered tests are useful when they protect different boundaries. Identical
assertions against the same command should have one clear owner.

## Ordered cleanup work

### 1. Correct false or weak evidence

- [x] exercise the real settings-layer detector;
- [x] replace the personal-app blacklist with resolved Nix assertions;
- [x] replace the restore-export source grep with flake evaluation;
- decide and test truthful `promote` failure semantics.

### 2. Give each contract one owner

- split `test_adoptability.bats` into focused suites;
- keep unit, integration, and clean-machine layers only when each catches a
  distinct failure;
- consolidate repeated setup-private-host and modular-template assertions.

### 3. Reduce brittle representation checks

- convert rebuild source greps to command-double tests;
- consolidate Node semver examples without losing boundary cases;
- replace exact documentation sentences with canonical-link, executable-help,
  and forbidden-claim contracts where possible.

### 4. Retire compatibility with the feature

Tests for the following remain required while the corresponding compatibility
path exists:

- top-level `install.sh`;
- `dot promote`;
- legacy `.local` application ownership;
- legacy host and `home.nix` layouts;
- the `DOTFILES_PRIVATE` environment-variable alias.

Deleting compatibility tests before deleting or explicitly ending support for
their feature would create an untested promise. The feature and its tests move
together in one reviewed change.

## Completion criteria

The integrity track is complete when:

- every suite has one documented responsibility;
- destructive and publication failures cannot report misleading success;
- tests invoke production behavior instead of recreating it;
- Nix configuration claims are asserted through evaluation;
- duplicated tests have been consolidated without losing boundary coverage;
- every compatibility-only group has an explicit retirement condition;
- `dot validate` still proves it executed the suite;
- physical clean-Mac and no-AI acceptance remain release gates independent of
  automated test count.
