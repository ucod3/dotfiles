# Product Contract

## Purpose

This repository contains the maintainer's working Apple Silicon macOS configuration framework, paired with a private profile containing personal choices. It is published as a reference for people comfortable reading and adapting Nix. It is not presented as a supported installer for first-time Nix users.

The generated configuration is ordinary, readable Nix. Someone with basic Nix, Git, and terminal knowledge can understand and edit it without learning a second proprietary configuration system. That is a design property of the code, not a promise of support.

## Status

What is demonstrated:

- The maintainer's Apple Silicon Mac is reproducibly configured by this framework through a private profile that pins a specific framework revision.
- That private profile is a normal Git repository, backed up to a private remote.
- Create, restore, activation, and rebuild paths are implemented, and their contracts are covered by automated tests and macOS flake evaluation in CI.

What is **not** demonstrated:

- Restoration onto a clean Mac.
- Restoration onto a second or replacement Mac.
- Completion of any journey by a first-time user without help.
- Recovery after a real factory reset — the event that originally motivated the project.

The clean-machine and replacement-machine paths are implemented and contract-tested, but have never been physically rehearsed. Green checks are evidence about code, not about hardware.

## Ownership model

### Public framework

`ucod3/dotfiles` contains reusable modules, safe defaults, installation tools, documentation, and thin convenience commands. It contains no user's hostname, username, application choices, adopted files, or personal preferences.

The framework is consumed as an upstream flake input. Using it does not require forking it. A fork is an option for someone intentionally maintaining a different engine.

The public installer is intended as a discovery and first-run entrance rather than the only recovery path. A user who already owns a private profile should be able to restore from that profile without returning to this repository for a separate restore implementation.

### Private profile

`~/dotfiles-private` is intended to be a portable, user-owned definition of a Mac. It holds hosts, application choices, macOS preferences, Home Manager configuration, adopted files, identity, and restore instructions. It is a normal, private Git repository and the source of truth for everything personal.

Its flake selects the reusable framework, conceptually:

```nix
inputs.dotfiles.url = "github:ucod3/dotfiles";
```

Its `flake.lock` records the exact framework revision used to apply those choices. Updating that input changes the framework implementation without rewriting the user's private choices.

The profile is designed to work as a standalone recovery artifact: a small profile-owned bootstrap installs or hands off prerequisites, and restore behaviour has one implementation supplied through the framework the profile already pins. Whether that design holds up against real replacement hardware is untested — see Status.

## Working with the configuration

The generated profile is ordinary Nix in clearly named files. The `dot` commands are conveniences that print the owning file and the equivalent native Nix or Git operation; they are learning aids, not a replacement platform layered over Nix. Anyone using this repository should expect to read and edit Nix directly. There is no supported beginner path.

Creation and restoration are separate journeys:

- **Create:** generate a readable local private profile, optionally connect a remote later, then rebuild.
- **Restore:** clone an existing private profile, preserve its framework input and lock, and rebuild through the profile's restore contract.

A user may decline to publish a private profile, but personal choices still live in a readable source of truth rather than hidden machine-local state.

## Design principles

- **Readable without AI.** The repository structure explains itself.
- **One source of truth.** Every user choice has one obvious editable location.
- **Separate data from behaviour.** Private files contain choices; public modules implement and validate them.
- **Cohesive modules.** Split by responsibility and reason to change, not by a target file count.
- **Thin commands.** Prefer standard Nix and Git operations over custom parsers, generators, and hidden state.
- **Safe defaults.** Destructive, opinionated, or publishing behaviour requires explicit consent.
- **Progressive disclosure.** Show the common path; let advanced users inspect and override the underlying system.
- **No abstraction without evidence.** Ordinary Nix remains the default until a demonstrated usability problem justifies more machinery.
- **Test user contracts.** Installation, framework updates, private-profile preservation, backup, restore, and destructive boundaries matter more than internal implementation details.
- **One restore engine.** Public installation and direct private-profile recovery converge on the same implementation.

## Project status

This project is maintenance-only. It is not working toward a further release, and there is no roadmap obligating future work. Known gaps are listed in [`README.md`](../README.md#known-gaps) and are recorded as limitations, not as planned work.
