# Operations

Day-two guide for applying, reviewing, updating, backing up, and recovering a
private profile. For first-run setup, see
[`GETTING-STARTED.md`](../GETTING-STARTED.md).

## Know which repository changed

| Change | Owning repository |
| --- | --- |
| Applications, hosts, macOS preferences, Home Manager choices, adopted files | `~/dotfiles-private` |
| Reusable modules, commands, templates, or framework documentation | `~/dotfiles` |
| Exact framework revision used by the Mac | `~/dotfiles-private/flake.lock` |

Most users change only the private profile. Updating the public checkout does
not by itself change the revision pinned by the private profile.

## Inspect the current profile

```bash
cd ~/dotfiles-private
git status --short
git log --oneline --decorate -5
./bootstrap --host "$(hostname -s)"
```

Preflight reports the selected host, framework source, pinned revision, and lock
without activating the Mac.

## Apply private-profile changes

```bash
dot rebuild
```

Rebuild resolves the current hostname through the private profile and applies
the revision recorded by its lock. It does not update `flake.lock`.

Before rebuilding:

```bash
git -C ~/dotfiles-private diff
git -C ~/dotfiles-private status --short
```

An unknown hostname stops instead of selecting another host. Use
`./bootstrap --add-host` to generate and stage a private host module for review,
`./bootstrap --rename-to EXISTING_HOST` to print a rename plan without running
it, or stop and inspect the profile. Host resolution never activates the Mac.
See [`PRIVATE_HOST_SETUP.md`](./PRIVATE_HOST_SETUP.md).

## Manage applications

```bash
dot apps list
dot apps search firefox
dot apps add ghostty
dot apps add --nix ripgrep
dot apps add --mas Notability 360593530
dot apps add --mas Notability \
  "https://apps.apple.com/us/app/notability/id360593530"
dot apps remove ghostty
dot apps edit casks
```

`dot apps search` is read-only. It points to official Homebrew and Nix package
sources. An App Store Copy Link is normalized to the numeric ID stored in Nix.

For a modular profile, the owning files are:

- `apps/homebrew-casks.nix`;
- `apps/nix-packages.nix`;
- `apps/mac-app-store.nix`.

Each mutation prints the exact file and equivalent manual Nix edit. If a file
contains an advanced hand-authored expression, the helper refuses to parse or
rewrite it.

Removing a declaration does not necessarily uninstall the application.
Homebrew cleanup remains `"none"` unless the owner explicitly chooses a
destructive cleanup policy.

## Adopt unmanaged configuration

Find portable candidates:

```bash
dot scan-unmapped
```

Preview and adopt:

```bash
dot adopt ~/.config/example --dry-run
dot adopt ~/.config/example
git -C ~/dotfiles-private diff
dot rebuild
```

The default mapping deploys a read-only Nix-store link. Edit the private copy
and rebuild.

Use `--mutable` when the application must keep writing the file:

```bash
dot adopt ~/.config/zed/settings.json --mutable
```

The application then writes through the link into the private repository.

Adoption refuses credential paths, destinations already owned by another
mapping, paths outside the home directory, and directories containing Home
Manager links. Adopt the specific unmanaged file inside a partially managed
directory instead.

New paths are staged because untracked files are invisible to flake evaluation.
They are not committed or pushed automatically.

## Back up the private profile

The private repository is the recovery artifact. A Git repository on the same
disk as the files it protects is not yet a backup.

Check its state:

```bash
git -C ~/dotfiles-private status --short --branch
git -C ~/dotfiles-private remote -v
dot scan-unmapped
```

Before publishing:

```bash
dot secrets ~/dotfiles-private
```

Then commit and push through the private Git remote you selected. Verify the
local branch tracks the remote and has no unpushed commits.

Git does not replace a password manager or system backup. SSH keys, app logins,
licence keys, databases, and personal documents do not belong in this profile.
The [private-profile backup guide](./PRIVATE_PROFILE_BACKUP.md) covers
provider-neutral remote setup, exact commit verification, recovery credentials,
and a non-activating restore rehearsal.

## Update the pinned framework

An ordinary profile updates the `dotfiles` input in its own lock:

```bash
cd ~/dotfiles-private
nix flake update dotfiles
git diff -- flake.lock
./bootstrap --host "$(hostname -s)"
```

The private flake follows the framework's `nixpkgs`, `nix-darwin`,
`home-manager`, and `nix-homebrew` inputs, so review the complete lock diff.

If preflight and evaluation are correct:

```bash
git add flake.lock
git commit -m "chore: update dotfiles framework"
git push
```

Activation remains separate:

```bash
./bootstrap --host "$(hostname -s)" --activate
```

Restore never performs this update automatically.

## Update applications

Nix-managed package versions move when the relevant pinned inputs move.
Homebrew metadata and declared Homebrew applications are applied during rebuild
and activation according to the nix-darwin Homebrew policy.

Keep update and restore conceptually separate:

```text
restore  → reproduce the committed known-good profile
update   → deliberately move reviewed dependency revisions
rebuild  → apply the reviewed pinned configuration
```

## Test local framework work

Framework contributors can evaluate a staged local checkout without changing
the stable private lock:

```bash
cd ~/dotfiles
git status --short
scripts/bin/dot validate
dot rebuild --override-local
```

`--override-local` uses `git+file:` semantics:

- staged changes are visible;
- untracked files are invisible;
- the private lock is not written;
- the next plain `dot rebuild` returns to the pinned revision.

This is an advanced framework-development path, not an ordinary profile update.

## Framework-maintainer commands

`dot update` and `dot promote` currently operate on the public framework
checkout. They are useful to the upstream maintainer or someone intentionally
running a writable framework fork.

```bash
dot update --dry-run
dot promote --dry-run
```

Important boundaries:

- `dot update` updates the public checkout's lock; that lock does not by itself
  drive a downstream private profile.
- `dot promote` expects permission to push the framework remote, moves the
  private profile's framework pin, scans and pushes the private repository when
  possible, and can rebuild.
- An ordinary upstream consumer should not use `dot promote` because they do not
  own `ucod3/dotfiles`.

These commands remain for compatibility and framework maintenance. The ordinary
user workflow is to update and commit the private profile's `dotfiles` input as
shown above.

## Roll back configuration

First separate the two kinds of rollback:

- Git changes what future builds declare.
- Nix generations change what is currently active.

Revert a private change:

```bash
cd ~/dotfiles-private
git log --oneline -10
git diff HEAD~1
git revert <commit>
dot rebuild
```

Revert a framework update by restoring the previous private lock:

```bash
cd ~/dotfiles-private
git log --oneline -- flake.lock
git checkout <known-good-commit> -- flake.lock
git diff -- flake.lock
dot rebuild
```

Prefer `git revert` for published history. Do not rewrite a private branch that
another Mac already consumes.

## Roll back an active generation

List and switch nix-darwin generations:

```bash
darwin-rebuild --list-generations
sudo darwin-rebuild --rollback
```

List Home Manager generations:

```bash
home-manager generations
```

Generation rollback can restore a working machine before the Git source is
fixed. Afterward, repair or revert the declarative source so the next rebuild
does not reintroduce the failure.

## Legacy profile compatibility

Existing profiles may still use:

- `.local/settings.nix`;
- `.local/identity.nix`;
- generated `.local/apps.nix`;
- root `home.nix` and legacy adopted-file storage.

Rebuild, application management, adoption, and host generation detect and retain
that layout. Do not reorganize a live legacy profile as part of an unrelated
operation.

The `.local` bridge requires impure evaluation and `DOTFILES_LOCAL` forwarding.
It remains load-bearing until the roadmap migration phase proves equivalent
modular values.

Preview the evidence without changing either repository:

```bash
dot migrate --preview
```

The inventory reports which legacy files are active through `.local`, which
Home Manager mappings are imported by host modules, which modular targets are
missing, and whether the private Git repository is clean and remotely tracked.
There is intentionally no apply mode.

## Shell customization

Framework shell modules provide neutral defaults. Personal, portable shell
configuration should live in the private profile or in an adopted file.

Two machine-local escape hatches remain available and are sourced last:

```text
~/dotfiles/config/zsh/custom.local.zsh
~/.zshrc.local
```

They are intentionally unmanaged and do not travel to another Mac unless the
owner adopts or otherwise backs them up.

## Secrets and hooks

```bash
dot secrets
dot secrets ~/dotfiles-private
dot hooks
```

The pre-commit hook runs quick validation and gitleaks. It fails closed. Fix the
reported problem instead of weakening or bypassing the check.

## When a rebuild fails

1. Read the first concrete Nix or activation error.
2. Run `dot validate` in the repository that changed.
3. Run private-profile preflight and confirm the intended host and pin.
4. Inspect `git diff` and `flake.lock`.
5. Use the previous Nix generation when the active system must be recovered.
6. Do not rerun activation repeatedly without understanding whether the source
   or machine state changed.
