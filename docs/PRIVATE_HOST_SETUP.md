# Private Profile and Host Setup

The public repository is a reusable framework. A concrete Mac requires a
hostname, username, application choices, preferences, and adopted files, so
those values live in the separate private profile at `~/dotfiles-private`.

For ordinary first-run instructions, use
[`GETTING-STARTED.md`](../GETTING-STARTED.md). This document explains the host
composition in more detail.

## Create the first host

The supported public entry point is:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --new
```

It clones the public framework, generates the private repository, writes the
current host module, creates and commits `flake.lock`, and finishes with
non-destructive preflight unless activation was explicitly requested.

The lower-level generator remains available from a framework checkout:

```bash
cd ~/dotfiles
./scripts/bin/setup-private-host \
  --host "$(hostname -s)" \
  --user "$(id -un)"
```

It refuses to overwrite an unrelated non-empty destination.

## Generated structure

```text
~/dotfiles-private/
├── README.md
├── bootstrap
├── flake.nix
├── flake.lock
├── identity.nix
├── hosts/
│   └── <hostname>.nix
├── apps/
├── macos/
├── home/
└── home.nix
```

The private flake enumerates `hosts/*.nix` and produces one
`darwinConfigurations.<hostname>` for each file. Keep supporting modules outside
`hosts/`; every `.nix` file there represents a buildable Mac.

## Framework selection

New profiles use the shared upstream framework:

```nix
inputs.dotfiles.url = "github:ucod3/dotfiles";
```

The private `flake.lock` pins an exact revision. Updating the framework changes
that lock without rewriting the user's host, app, macOS, or home files.

An advanced maintainer can generate a profile against a compatible fork:

```bash
./scripts/bin/setup-private-host --fork OWNER/REPOSITORY
```

Using the framework does not otherwise require a fork.

## Host composition

A generated host imports the focused private modules and the framework's Home
Manager environment:

```nix
{
  imports = [
    ../apps
    ../macos
  ];

  home-manager.users.${user}.imports = [
    inputs.dotfiles.darwinModules.homeEnvironment
    ../home
  ];
}
```

The same host enables `nix-homebrew` for its user. Applications remain in the
private `apps/` files; personal Home Manager settings remain in `home/`.

## Restore a known host

Through the public installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git
```

Or directly:

```bash
git clone git@github.com:you/dotfiles-private.git ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap --host "$(hostname -s)"
```

Both paths use the profile-owned restore contract and its committed lock.
Preflight does not activate.

## Add another Mac deliberately

The restore command currently stops when the Mac's hostname is absent. That is
intentional: it must not silently reuse another host.

The profile-owned restore command provides the beginner-facing path:

```bash
cd ~/dotfiles-private
./bootstrap \
  --host "$(hostname -s)" \
  --add-host \
  --user "$(id -un)"
```

It delegates to the lower-level generator, stages the generated module so Nix
can see it, prints the native review commands, and stops before evaluation or
activation. The same generator can be run directly for advanced use:

```bash
cd ~/dotfiles
./scripts/bin/setup-private-host \
  --host "$(hostname -s)" \
  --user "$(id -un)"
git -C ~/dotfiles-private diff -- hosts/
git -C ~/dotfiles-private status --short
```

It stages the new host because Nix evaluation cannot see an untracked file. The
owner must review, commit, scan, and push the private change before relying on it
for recovery.

To retain an existing host identity instead, print a rename plan:

```bash
cd ~/dotfiles-private
./bootstrap --host "$(hostname -s)" --rename-to EXISTING_HOST
```

The restore command never runs the privileged rename commands. The owner reviews
and runs them separately, or stops without changing anything.

## Back up the profile

`~/dotfiles-private` is a normal Git repository and is not a backup while it
exists only on the Mac it protects.

Connect it to a private Git remote, scan it for credentials, push every intended
commit, and verify the local branch tracks the remote. The framework is
provider-neutral; GitHub is not required.

Never publish a private profile merely because its filename contains
“dotfiles.” It can contain hostnames, usernames, application choices, and
adopted personal configuration.

## Existing legacy profiles

Profiles created before the modular layout may still use root `settings.nix`,
`home.nix`, and the `.local` bridge. `setup-private-host`, `dot apps`, rebuild,
and adoption retain compatibility with that shape.

No setup or restore command is permission to reorganize a live private profile.
