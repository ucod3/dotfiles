# Product Contract

## Purpose

This project is a public, reusable macOS configuration framework paired with a private, user-owned profile.

A person with a clean Apple Silicon Mac, no Nix knowledge, and no AI assistance must be able to install the framework, choose their own applications, create and back up their private configuration, rebuild successfully, and later restore the same setup on another Mac.

The generated configuration must remain ordinary, readable Nix. A person with basic Nix, Git, and terminal knowledge should be able to understand and edit it without learning a second proprietary configuration system.

## Ownership model

### Public framework

`ucod3/dotfiles` contains reusable modules, safe defaults, installation tools, documentation, and thin convenience commands. It contains no user's hostname, username, application choices, adopted files, or personal preferences.

Ordinary users consume the upstream framework directly. They do not need to fork it merely to use it.

The public installer is a convenient discovery and first-run entrance, not the only recovery path. A user who already owns a private profile must be able to restore from that profile without returning to this repository for a separate restore implementation.

### Private profile

`~/dotfiles-private` is a complete, portable, user-owned definition of the user's Mac. It contains the user's hosts, application choices, macOS preferences, Home Manager configuration, adopted files, identity, and restore instructions. It is a normal, private Git repository and the source of truth for everything personal.

Its flake selects the reusable framework, conceptually:

```nix
inputs.dotfiles.url = "github:ucod3/dotfiles";
```

Its `flake.lock` records the exact framework revision used to apply those choices. Updating that input changes the framework implementation without rewriting the user's private choices.

The private profile must be independently usable as a recovery artifact. A small profile-owned bootstrap may install or hand off prerequisites, but restore behavior has one implementation supplied through the framework the profile already pins.

A framework fork is an advanced option for contributors or people intentionally maintaining a different engine. It is not an installation prerequisite.

## User experience

The project supports three levels without forcing one level to understand the next.

1. **Beginner:** installs, selects applications, rebuilds, updates, backs up, and restores through documented commands.
2. **Intermediate:** edits clearly named, focused Nix files in the private profile.
3. **Advanced:** uses native Nix, nix-darwin, Home Manager, and Git commands, adds modules, or points the private profile at a framework fork.

Convenience commands must reveal the files and native operations they use. They are learning aids, not a replacement platform layered over Nix.

Creation and restoration are separate journeys:

- **Create:** generate a readable local private profile, optionally connect a remote later, then rebuild.
- **Restore:** clone an existing private profile, preserve its framework input and lock, and rebuild through the profile's restore contract.

A user may decline to publish a private profile, but personal choices must still live in a readable source of truth rather than hidden machine-local state.

## Design principles

- **Readable without AI.** The repository structure explains itself.
- **One source of truth.** Every user choice has one obvious editable location.
- **Separate data from behaviour.** Private files contain choices; public modules implement and validate them.
- **Cohesive modules.** Split by responsibility and reason to change, not by a target file count.
- **Thin commands.** Prefer standard Nix and Git operations over custom parsers, generators, and hidden state.
- **Safe defaults.** Destructive, opinionated, or publishing behaviour requires explicit consent.
- **Progressive disclosure.** Beginners see the common path; advanced users can inspect and override the underlying system.
- **No abstraction without evidence.** Ordinary Nix remains the default until a demonstrated usability problem justifies more machinery.
- **Test user contracts.** Installation, framework updates, private-profile preservation, backup, restore, and destructive boundaries matter more than internal implementation details.
- **One restore engine.** Public installation and direct private-profile recovery converge on the same implementation.

## Definition of success

The clean-machine journey is the product:

1. Install the public framework without creating a framework fork.
2. Generate a private profile whose folders and filenames explain their roles.
3. Choose applications and preferences without editing the public framework.
4. Rebuild successfully.
5. Push the private profile to a private remote and verify it is backed up, or clearly understand that a local-only profile is not yet backed up.
6. Update the public framework while preserving all private choices.
7. Restore the profile on a second or replacement Mac through the public installer.
8. Restore the same profile directly from its own repository using its profile-owned entry point.
9. Preserve the profile's existing framework source and committed lock during restoration.
10. Understand and manually modify the generated Nix with basic Nix knowledge.

Green checks do not substitute for completing these journeys on a clean Mac.

## Migration direction

Preserve the public/private separation. Simplify the private profile so it imports the public framework normally and groups user-owned configuration into clear areas such as `hosts/`, `apps/`, `macos/`, and `home/`.

Existing installations must continue to work during migration. New structure and self-restore entry points should be introduced without rewriting or endangering a live private profile.

The detailed portability and restore design is documented in [`PORTABLE_PRIVATE_PROFILE.md`](./PORTABLE_PRIVATE_PROFILE.md).
Implementation sequence and release gates are tracked in
[`ROADMAP.md`](./ROADMAP.md).
