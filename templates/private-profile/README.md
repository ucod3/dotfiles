# My macOS Profile

This private repository is the complete, user-owned definition of your Mac. It
contains your choices and records the exact framework revision used to apply
them.

The reusable framework is selected in `flake.nix` and pinned in `flake.lock`.
The default source is `@DOTFILES_REF@`, but the profile remains the source of
truth for your hosts, applications, preferences, identity, and adopted files.

## Where to make changes

- `apps/homebrew-casks.nix` — GUI applications installed with Homebrew.
- `apps/nix-packages.nix` — command-line tools installed with Nix.
- `apps/mac-app-store.nix` — Mac App Store applications and numeric IDs.
- `macos/default.nix` — your macOS preferences.
- `hosts/@HOSTNAME@.nix` — settings specific to this Mac and username.
- `home/default.nix` — private Home Manager settings that you edit yourself.
- `home/files/` — files stored by `dot adopt` and restored into your home directory.
- `home.nix` — generated adopted-file mappings; normally changed by `dot adopt`.
- `identity.nix` — personal identity data used by modules you explicitly import.

`home/default.nix` imports the generated root `home.nix`. This keeps your
hand-written Home Manager settings separate from the section maintained by
`dot adopt`, while preserving compatibility with older private profiles.

## Restore entry point

This profile owns a stable recovery entrance:

```bash
./bootstrap
```

`bootstrap` performs only prerequisite work. It checks macOS and the target
architecture, ensures the Xcode Command Line Tools and Nix are available, then
runs the native profile command:

```bash
nix run .#restore
```

The restore implementation comes from the framework revision already pinned in
this profile's `flake.lock`. The bootstrap does not contain a copied restore
engine, replace the framework input, or update the lock file.

Without activation, restore is a **non-destructive preflight**. It reports the
profile, remote, host, available hosts, framework source, pinned revision, and
lock file. It refuses dirty repositories, incomplete profiles, and unknown
hostnames.

After reviewing that plan, activate deliberately:

```bash
./bootstrap --activate
```

The command prints the exact `darwin-rebuild` invocation and asks you to type the
full confirmation phrase for the selected hostname. For deliberately unattended
recovery only, use:

```bash
./bootstrap --activate --yes
```

Activation uses the host and framework revision already pinned by this profile,
passes `--no-write-lock-file`, and verifies that `flake.lock` remains unchanged.

## Restore on another Mac

After pushing this repository to a private Git remote, the owner-controlled path
is:

```bash
git clone <private-profile-repository> ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap
./bootstrap --activate
```

You do not need to return to the framework repository to obtain a separate
restore implementation. A public installer may provide a convenient discovery
path, but it must invoke this same profile contract rather than make new
framework or configuration decisions.

When the new Mac has a different hostname, preflight and activation stop instead
of selecting another host silently. Review the available hosts, deliberately add
a new file under `hosts/`, rename the Mac, or stop and inspect the profile.

## Normal workflow

1. Edit one focused Nix file.
2. Review the change with `git diff`.
3. Check the profile:

   ```bash
   nix flake check
   ```

4. Rebuild this Mac:

   ```bash
   darwin-rebuild switch --flake .#@HOSTNAME@
   ```

The `dot rebuild` command is a convenience wrapper around the same flake.

## Manage applications

The optional `dot apps` helper changes the same ordinary Nix files listed above:

```bash
dot apps list
dot apps add firefox
dot apps add --nix ripgrep
dot apps add --mas Notability 360593530
git diff -- apps/
dot rebuild
```

Each command names the file it changed and shows the equivalent manual edit.
You may always edit `apps/homebrew-casks.nix`, `apps/nix-packages.nix`, or
`apps/mac-app-store.nix` directly. The helper refuses to rewrite a file that no
longer has the generated plain-list or plain-attribute-set shape.

Removing a cask declaration does not uninstall the application while
`dotfiles.homebrew.cleanup` remains `"none"`, which is the safe default.

## Adopt an existing configuration file

```bash
dot adopt ~/.config/example
git diff -- home.nix home/files/
dot rebuild
```

Use `dot adopt --mutable` when the application must keep writing to the file.
The command updates `home.nix` and stores the file beneath `home/files/`.

## Update the framework

Updating the framework changes only `flake.lock`; it does not rewrite your app
lists, preferences, hosts, or adopted files.

```bash
nix flake update dotfiles
git diff -- flake.lock
```

Evaluate or rebuild before committing the lock-file change.

## Back up the profile

Push this repository to a **private** Git remote. A repository that exists only
on the same Mac is not a backup.

The recovery artifact includes `flake.nix`, the committed `flake.lock`, every
host file, and all private configuration. Do not publish secrets or unreviewed
personal data.

## Generated files

- `flake.lock` is generated by Nix; do not edit it manually.
- The marked section in root `home.nix` may be updated by `dot adopt`.
- Everything else is ordinary Nix or shell that you may read and edit directly.
