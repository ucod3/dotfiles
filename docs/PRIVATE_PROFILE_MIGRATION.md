# Existing Private-Profile Migration

## Current support

Existing profiles remain supported through the `.local` compatibility bridge.
Migration is optional and is never started from the presence of a directory or
file alone.

The current command is read-only:

```bash
dot migrate --preview
```

It reports which legacy files are active by evidence, which modular targets
exist, and whether Git is clean and backed by an upstream remote. It does not
create a branch, move files, stage changes, evaluate a host, rebuild, or
activate macOS.

Application-specific evidence is available with:

```bash
dot migrate --preview --applications
```

That mode reports:

- the active legacy application source files;
- declaration counts for Homebrew casks, Nix packages, and App Store apps;
- a fingerprint of the resolved legacy declarations without printing the
  user's application names;
- the expected focused files under `apps/`;
- a second fingerprint and exact-equivalence result when all modular
  application files already exist.

The fingerprint is evidence for comparing the two layouts during migration. It
is not a backup and does not replace reviewing the private diff.

## Application migration boundary

The first writable migration slice will move only application declarations:

```text
settings.nix / apps.nix
        │
        ├── apps/homebrew-casks.nix
        ├── apps/nix-packages.nix
        ├── apps/mac-app-store.nix
        └── apps/default.nix
```

It must preserve the exact resolved cask list, Nix package list, and App Store
attribute set. Other legacy choices—including Homebrew cleanup, macOS defaults,
Home Manager options, AI settings, identity, hosts, and adopted files—remain in
their existing sources for later responsibility-specific slices.

The `.local` bridge remains active throughout this phase. Removing it requires
completed migration evidence and a separate compatibility decision.

## Preconditions for a writable slice

Before any private file is created or edited:

1. The private repository working tree is clean.
2. The current branch is backed up to its configured upstream.
3. A dedicated private migration branch is created.
4. The application preview records the legacy declaration fingerprint.
5. The proposed diff changes application ownership only.

Staged or unstaged personal settings are a blocker. The migration tool must not
stash, discard, commit, or publish those changes on the user's behalf.

## Review and validation sequence

Each responsibility moves independently:

1. Generate or hand-edit the focused private files on the migration branch.
2. Import `apps/default.nix` from the private host.
3. Remove only the application declarations now owned by `apps/`.
4. Run the application preview again and require an exact fingerprint match.
5. Parse every changed Nix file.
6. Evaluate the private host without activation.
7. Review the private diff and commit it.
8. Move to the next responsibility only after the current one is proven.

A live switch remains separately approved. Public validation and a private host
evaluation do not authorize `darwin-rebuild switch`.
