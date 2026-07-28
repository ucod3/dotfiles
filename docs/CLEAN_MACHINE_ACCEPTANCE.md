# Clean-machine acceptance proof

The product acceptance test is:

> A person with a clean Apple Silicon Mac, no Nix knowledge, and no AI
> assistance can install the framework, choose their own applications, create
> and back up their private configuration, rebuild successfully, and later
> restore the same setup on another Mac.

This document prevents a collection of passing unit tests from being mistaken
for proof of that whole statement. Each clause has an explicit evidence type and
status.

## Evidence levels

- **Automated contract** — runs in CI with temporary directories, command doubles,
  or Nix evaluation. It proves deterministic behavior without changing a Mac.
- **Hardware rehearsal** — performed on a clean Apple Silicon Mac. It is required
  for privileged installation, nix-darwin activation, Homebrew behavior, and
  restart/login effects that CI cannot faithfully simulate.
- **Human usability** — completed by a person following only the public
  documentation. It is required for claims such as “no Nix knowledge” and “no AI
  assistance,” which cannot be established by shell assertions.

## Acceptance matrix

| Acceptance clause | Automated evidence | Remaining evidence | Status |
| --- | --- | --- | --- |
| Start from a clean Apple Silicon Mac | `setup.sh` refuses non-macOS systems, checks Xcode Command Line Tools, and generated profiles carry an `aarch64-darwin` target. macOS CI evaluates the flake. | A clean-hardware run must prove the installer, Nix daemon setup, Rosetta behavior, and restart boundaries. | Partial |
| Install without Nix knowledge | The public entry point chooses `--new` or `--restore`; generated profiles contain a tiny `bootstrap` command and ordinary files. | A first-time user must complete the documented journey without editing Nix or receiving undocumented help. | Human proof required |
| Choose applications | Generated profiles own readable `apps/homebrew-casks.nix`, `apps/nix-packages.nix`, and `apps/mac-app-store.nix`; `setup.sh --new` offers interactive selection, official read-only discovery paths, App Store URL input, and repeatable flags through the profile-aware `dot apps` implementation. The two-machine test selects applications through the public installer and proves those declarations survive backup and restore. | A first-time user must complete the interactive application workflow without undocumented help. | Human proof required |
| Create a private configuration | The real generator creates the documented modular layout, initializes Git through `setup-private-host`, commits a lock, and enters profile-owned preflight. | Human review must confirm the generated names and choices are understandable. | Automated contract |
| Back up the private configuration | The two-machine test publishes the profile to a real temporary bare Git remote and restores from that remote. `PRIVATE_PROFILE_BACKUP.md` documents provider-neutral scanning, remote connection, exact commit verification, recovery limits, and non-activating rehearsal. A local private-remote rehearsal completed that documented restore contract. | A clean-hardware run must prove account authentication and recovery on a replacement Mac. | Automated contract + local rehearsal |
| Rebuild successfully | Restore activation tests prove explicit confirmation, exact host forwarding, pinned `darwin-rebuild`, and lock preservation. macOS CI evaluates the configuration. | A clean-hardware `darwin-rebuild switch` must complete, followed by a post-activation preflight and application checks. | Hardware proof required |
| Restore the same setup on another Mac | `tests/test_clean_machine_acceptance.bats` creates a profile on simulated Mac A, commits application choices, pushes to a real bare remote, restores through `setup.sh` on simulated Mac B, and compares the exact commit, Git tree, lock, and app files. Unknown-host tests prove the default stop, reviewed host generation, printed rename plan, cancellation, lock preservation, and separate activation. | A second physical Mac must prove credentials, the selected host-resolution path, Homebrew downloads, and activation behavior. | Automated contract |
| Complete the journey without AI | Commands and generated files are standalone and documented; no runtime path calls an AI service. | A human usability rehearsal must be completed without AI assistance. | Human proof required |

## Automated two-machine proof

`tests/test_clean_machine_acceptance.bats` exercises one continuous chain instead
of testing isolated helper functions:

1. Simulated Mac A runs the public `setup.sh --new` journey.
2. The real framework checkout and real private-profile generator create the
   profile.
3. A deterministic Nix double creates an exact committed lock and records
   profile-owned preflight without installing or activating anything.
4. The public installer delegates reviewed application selections to the
   profile-aware application command and commits the profile-owned `apps/`
   modules.
5. Real Git publishes the profile to a temporary bare private remote.
6. Simulated Mac B runs `setup.sh --restore` against that remote.
7. The restored checkout must match the exact source commit and tree, remain
   clean, preserve the lock and application files byte-for-byte, avoid a separate
   framework checkout, and request no activation.

The test uses real Git storage and history. Only macOS prerequisites and Nix
execution are doubled, because CI must never install Nix or switch a host.

## Local interactive rehearsal — 2026-07-28

Framework commit `a5dee71094e8392e8d0aa541cab9981540c9d113` completed a
real interactive `setup.sh --new` rehearsal on macOS using isolated temporary
framework, profile, and home directories.

The public installer cloned the upstream framework, generated and committed a
modular private profile, accepted one application from each supported category,
showed the ordinary Nix diff, created a separate application commit, and
completed profile-owned restore preflight with an unchanged lock. The generated
private repository was clean afterward, and no activation occurred.

This is useful local integration evidence, but it is not clean-hardware or
no-AI proof: Nix and Git were already installed, inputs were supplied during the
rehearsal, and no nix-darwin or Homebrew activation ran. The later discovery
workflow addressed the identifier guidance found during this rehearsal, but
still requires first-time-user validation.

## Local private-remote restore rehearsal — 2026-07-28

The public `setup.sh --restore` journey cloned an existing private profile from
its remote into an isolated temporary directory. Profile-owned preflight
reported the intended host, remote, framework source, and pinned revision,
preserved `flake.lock`, performed no activation, and left the restored Git tree
clean. The temporary directory was removed after verification.

This proves that the documented remote can recover the committed profile on an
already configured Mac. It does not replace the Phase 5 clean-hardware proof of
account recovery, first-time authentication, or activation on a replacement
machine.

## What passing CI does not prove

Passing CI does not establish that:

- the official Nix installer behaves correctly on a newly erased Mac;
- a user understands the prompts and terminology;
- Apple, Homebrew, or Mac App Store authentication succeeds;
- all declared applications are currently available;
- nix-darwin activation and login/restart effects are correct;
- the journey is usable without prior Nix knowledge;
- a remote repository is private or protected by appropriate account security.

These remain explicit manual evidence, not implied guarantees.

## Manual hardware rehearsal

Use a disposable or newly erased Apple Silicon Mac. Do not perform this checklist
on a production machine merely to satisfy documentation.

### Mac A — new profile

1. Start with no Nix installation and no `~/dotfiles` or
   `~/dotfiles-private` directory.
2. Follow only `docs/INSTALLER_MODES.md` and choose the new-profile journey.
3. Record every prompt that requires unexplained Nix or Git knowledge.
4. Select applications through the supported beginner workflow, including its
   read-only package discovery and App Store Copy Link path.
5. Review the generated private profile and confirm the chosen applications and
   hostname are visible in ordinary files.
6. Create a private remote, push the profile, and verify the local branch has an
   upstream with no unpushed commits.
7. Run preflight, then approve activation separately.
8. Confirm activation completes and `flake.lock` remains unchanged.
9. Restart or log in again when instructed, then verify shell, applications, and
   managed files.

### Mac B — restore

1. Start with a second clean Apple Silicon Mac.
2. Follow only the restore documentation and provide the private repository.
3. Confirm the installer clones no separate framework checkout.
4. Confirm preflight reports the intended profile, remote, host, framework pin,
   and unchanged lock.
5. Confirm an unknown hostname stops rather than selecting another host.
6. Resolve the host deliberately, approve activation separately, and verify the
   same declared applications and managed files.
7. Confirm the private checkout remains clean after activation.

Record the date, macOS version, hardware model, public framework commit, private
profile commit, observed prompts, failures, and any undocumented intervention.
Never include private repository contents, credentials, or personal application
choices in a public evidence report.

## Current verdict

The framework now has automated proof for profile creation, Git-backed backup,
application selection, exact restore continuity, preflight defaults, and lock
preservation, plus a successful isolated interactive macOS rehearsal. The
overall product acceptance test is **not yet complete**.

The project still requires first-time-user validation of package discovery, a
documented clean-hardware rehearsal, and a no-AI usability run before the full
acceptance statement can be marked proven.
