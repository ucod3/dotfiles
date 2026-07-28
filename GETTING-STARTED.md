# Getting Started

This guide covers the current public setup journey for an Apple Silicon Mac.
The project uses a public framework plus a private, user-owned profile.

You do not need to understand Nix to follow the ordinary path. The generated
files remain readable Nix so you can learn from and edit them later.

## Before you start

You need:

- an Apple Silicon Mac;
- an administrator account for prerequisite installation and activation;
- internet access;
- access to your private Git remote when restoring.

The setup command checks Xcode Command Line Tools and Git, installs Nix when it
is missing, and keeps activation separate from inspection.

## Choose a journey

Start the interactive installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh)
```

Choose:

1. **Create a new private profile** for a Mac that does not have one.
2. **Restore an existing private profile** from a private Git remote.

Use the process-substitution form shown above. A plain `curl ... | bash` pipeline
uses the script as standard input and prevents interactive prompts from reading
your answers reliably.

## Create a new private profile

The explicit create command is:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --new
```

Setup will:

1. verify the supported Mac and prerequisites;
2. install Nix if it is absent;
3. clone `ucod3/dotfiles` into `~/dotfiles`;
4. ask for Git identity only if none is already available;
5. generate `~/dotfiles-private` as a normal Git repository;
6. optionally collect application choices;
7. create and commit `flake.lock`;
8. run a non-destructive restore preflight.

Ordinary users track `github:ucod3/dotfiles`. They do not need to fork the
framework. `--framework` remains available for an advanced user who deliberately
maintains a compatible fork.

### Choose applications

Interactive setup uses plain categories:

1. Mac applications installed with Homebrew.
2. Command-line tools installed with Nix.
3. Mac App Store applications.
4. Read-only help finding a package name.

Package discovery points to official sources and changes nothing. For an App
Store application, choose **Copy Link** in the App Store and paste the complete
Apple URL.

For repeatable non-interactive setup:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --new \
  --cask firefox \
  --cask ghostty \
  --nix-package ripgrep \
  --mas-app "Notability=https://apps.apple.com/us/app/notability/id360593530"
```

Use `--skip-apps` to create an application-neutral profile and configure it
later.

### Review the generated profile

The private repository is the source of truth for personal choices:

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

Common edits:

- `apps/homebrew-casks.nix` — Mac applications installed through Homebrew.
- `apps/nix-packages.nix` — command-line packages from Nixpkgs.
- `apps/mac-app-store.nix` — App Store names and numeric IDs.
- `macos/default.nix` — personal macOS preferences.
- `home/default.nix` — personal Home Manager configuration.
- `hosts/<hostname>.nix` — composition specific to one Mac.

Inspect the repository before activating:

```bash
cd ~/dotfiles-private
git status --short
git log --oneline --decorate -5
./bootstrap --host "$(hostname -s)"
```

Preflight reports the profile, remote, available hosts, framework source, pinned
revision, and unchanged lock. It does not activate the Mac.

### Activate explicitly

After reviewing preflight:

```bash
cd ~/dotfiles-private
./bootstrap --host "$(hostname -s)" --activate
```

The command prints the exact activation plan and asks you to type the hostname
confirmation. Enter your macOS password only when `sudo` requests it.

During activation:

- `nix-homebrew` installs or adopts Homebrew;
- nix-darwin installs declared Homebrew formulae, casks, and App Store apps;
- Home Manager installs user packages and applies home configuration;
- nix-darwin applies the selected system and macOS settings;
- the committed `flake.lock` remains unchanged.

The safe Homebrew cleanup default is `"none"`, so an incomplete list does not
remove undeclared software.

## Restore an existing private profile

From the public setup entry point:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git
```

Restore:

1. installs or hands off prerequisites;
2. clones only the private profile into `~/dotfiles-private`;
3. requires the profile's committed `flake.nix`, `flake.lock`, and `bootstrap`;
4. invokes the profile-owned restore contract;
5. preserves its framework source and pinned revision;
6. runs preflight unless activation was explicitly requested.

It does not rerun application or identity questions, regenerate profile files,
update the lock, or choose another host silently.

If the current hostname is not already in `hosts/`, restore stops. The explicit
new-host workflow is a queued roadmap phase; do not copy or rename a host
configuration without reviewing what is machine-specific.

### Restore directly from the private repository

The public installer is a convenience, not a permanent dependency:

```bash
git clone git@github.com:you/dotfiles-private.git ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap
```

The private `flake.nix` and `flake.lock` select the framework and exact revision.
Both public-installer restore and direct restore use the same framework-owned
engine.

## Manage applications

After setup:

```bash
dot apps list
dot apps search firefox
dot apps add firefox
dot apps add --nix ripgrep
dot apps add --mas Notability \
  "https://apps.apple.com/us/app/notability/id360593530"
git -C ~/dotfiles-private diff -- apps/
dot rebuild
```

Each mutation names the private file it changed and shows the equivalent manual
Nix edit. You may edit the focused files directly instead.

Removing a declaration does not necessarily uninstall an existing application.
Homebrew pruning remains disabled while `dotfiles.homebrew.cleanup = "none"`.

## Turning things on

Personal preferences belong in the private profile, never in the public
framework.

For a newly generated modular profile:

- edit `macos/default.nix` for macOS preferences;
- edit `home/default.nix` for Home Manager preferences and imports;
- edit `hosts/<hostname>.nix` only for settings specific to that Mac;
- keep application choices in the three files under `apps/`.

Existing installations may still use `.local/settings.nix`. That is a supported
legacy compatibility path, not the format generated for new users. Existing
profiles are not migrated automatically.

## Adopt existing configuration

To bring a portable file under private-profile management:

```bash
dot adopt ~/.config/example
git -C ~/dotfiles-private diff
dot rebuild
```

Use `--mutable` when the application must keep saving to that file:

```bash
dot adopt ~/.config/zed/settings.json --mutable
```

Audit unmanaged paths first:

```bash
dot scan-unmapped
```

Never adopt SSH keys, credentials, app sessions, caches, histories, or other
machine-local state. Store secrets in a password manager and use Time Machine or
another system backup for data that does not belong in Git.

## Backing it up

The generated `~/dotfiles-private` Git repository exists only on the new Mac
until you connect and push a private remote. It is not a backup while it remains
on the same disk.

Any private Git host is acceptable. The recovery requirement is that the
replacement Mac can authenticate, clone the repository, and obtain every
committed profile change.

At minimum, verify:

```bash
cd ~/dotfiles-private
git status --short
git remote -v
git status --branch --short
```

`dot scan-unmapped` also reports uncommitted private changes, unpushed commits,
and a missing remote as **AT RISK**.

Follow the
[private-profile backup guide](./docs/PRIVATE_PROFILE_BACKUP.md) to scan the
profile, connect any private Git remote, verify the exact pushed commit, and
rehearse a non-activating restore. Do not put SSH private keys, access tokens,
app logins, or licence keys in the profile.

## Update the framework

Framework code and personal choices have separate histories.

To review a newer framework revision:

```bash
cd ~/dotfiles-private
nix flake update dotfiles
git diff -- flake.lock
```

Updating the `dotfiles` input changes the pinned framework and its followed Nix
inputs. It does not rewrite the private application, host, macOS, or home files.
Evaluate and review the lock change before committing or activating it.

For the full update, rollback, and generation workflows, see
[docs/OPERATIONS.md](./docs/OPERATIONS.md).

## Troubleshooting

### `dot: command not found`

The `dot` command reaches the shell through activation. Before the first
successful activation, use the profile-owned `./bootstrap` commands shown above.
Open a new terminal after activation.

### Restore says the hostname is unknown

Stop rather than selecting a different host. Confirm the current short hostname:

```bash
hostname -s
```

Known hosts are the `.nix` filenames under `~/dotfiles-private/hosts/`. The
framework intentionally refuses to guess which one belongs to the Mac.

### A profile is dirty during restore

Restore requires a clean, committed source of truth before activation. Review:

```bash
cd ~/dotfiles-private
git status --short
git diff
```

Commit, discard, or deliberately preserve those changes before rerunning
preflight. Do not bypass the check.

### Nix reports that flakes are disabled

The framework commands supply the required experimental features. Prefer
`./bootstrap`, `dot`, or the documented commands instead of inventing a separate
Nix invocation.

### Setup finds an existing destination

The installer refuses to overwrite `~/dotfiles` or `~/dotfiles-private`.
Inspect the existing directory and decide whether it is the checkout you intend
to use. Presence is never treated as consent to move or replace it.

## Next references

- [Installer modes](./docs/INSTALLER_MODES.md)
- [Day-two operations](./docs/OPERATIONS.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Clean-machine acceptance](./docs/CLEAN_MACHINE_ACCEPTANCE.md)
- [Product roadmap](./docs/ROADMAP.md)
