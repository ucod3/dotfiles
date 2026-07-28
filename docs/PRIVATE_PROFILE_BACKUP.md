# Back Up and Rehearse a Private Profile

`~/dotfiles-private` is the recovery artifact for your configured Mac. A Git
repository stored only on that Mac is version history, not a backup.

This guide uses standard Git operations and does not require a particular
hosting provider. The remote may be a private repository on a hosted service, a
Git server you control, or another Git destination that the replacement Mac can
authenticate to and clone.

## What this backup contains

The private profile should contain the committed definition of the Mac:

- `flake.nix` and the exact framework revision in `flake.lock`;
- host and identity modules;
- application declarations;
- macOS and Home Manager choices;
- adopted configuration files that passed review.

It intentionally does not replace a password manager or whole-system backup.
SSH private keys, access tokens, app logins, licence keys, Keychain contents,
databases, personal documents, caches, and application data do not belong in
this Git repository. Use a password manager and Time Machine or another system
backup for those.

## 1. Review the local profile

Work from the private repository:

```bash
cd ~/dotfiles-private
git status --short --branch
git diff
git log --oneline --decorate -5
dot scan-unmapped
```

Review every changed and untracked path. Commit only configuration that you
recognize and intend to restore. `dot scan-unmapped` identifies backup risk and
known unsafe paths, but no scanner can prove that a repository contains no
private or credential material.

If `dot` is not on `PATH` before the first activation, run the same command
through the framework checkout:

```bash
~/dotfiles/scripts/bin/dot scan-unmapped
```

## 2. Scan before publishing

If `dot` is already installed:

```bash
dot secrets "$PWD"
```

Before the first activation, use the framework checkout created by `setup.sh`.
Nix supplies the scanner without requiring Homebrew:

```bash
nix shell nixpkgs#gitleaks -c gitleaks detect \
  --source "$PWD" \
  --config ~/dotfiles/.gitleaks.toml \
  --redact
```

Stop if the scan reports a finding. Remove the unsafe value and determine
whether it already exists in Git history before publishing. Deleting it only
from the latest file does not remove it from older commits. Rotate any exposed
credential; history cleanup does not make an already exposed credential safe
again.

## 3. Create an empty private remote

Create an empty repository through the Git host you chose:

- mark it **private** before the first push;
- do not initialize it with a README, licence, or `.gitignore`;
- enable multifactor authentication and account-recovery methods;
- make sure a replacement Mac can recover the SSH key or HTTPS credential
  needed to clone it.

Git itself cannot create an account or set a provider's repository visibility,
so this is the one provider-specific step. The framework does not require
GitHub, GitLab, or any other particular host.

## 4. Connect and push

Inspect existing remotes before changing anything:

```bash
cd ~/dotfiles-private
git remote -v
```

If no `origin` exists, set `private_remote` to the clone URL shown by your Git
host, then add it:

```bash
private_remote='ssh://git@your-host.example/you/dotfiles-private.git'
git remote add origin "$private_remote"
```

If `origin` already exists, do not overwrite it blindly. Review the URL first.
Use `git remote set-url origin "$private_remote"` only when changing that
destination is deliberate.

Commit the reviewed profile, then push its current branch:

```bash
git status --short
git add <reviewed-paths>
git diff --cached
git commit -m "chore: back up private profile"
git push --set-upstream origin "$(git branch --show-current)"
```

Never use `git add .` as a substitute for reviewing private files.

## 5. Verify the remote copy

Fetch the remote state and compare the exact commits:

```bash
git fetch origin
git status --short --branch
git log --oneline '@{upstream}..HEAD'
test "$(git rev-parse HEAD)" = "$(git rev-parse '@{upstream}')" \
  && echo "Private profile is pushed at the current commit"
```

The log command should print nothing, the status should show no unexpected
changes, and the commit comparison should print the success message.

This proves the selected branch reached the configured Git remote. It cannot
prove that the provider marked the repository private; verify visibility in the
provider's access settings as a separate human check.

## 6. Rehearse a non-destructive restore

Do not wait for the original Mac to fail before testing the remote. Clone it
into a temporary directory and run the normal public restore journey without
activation:

```bash
rehearsal_root="$(mktemp -d -t dotfiles-restore-rehearsal)"

bash ~/dotfiles/setup.sh \
  --restore "$private_remote" \
  --profile-dir "$rehearsal_root/dotfiles-private" \
  --host "$(hostname -s)"
```

The expected result is restore preflight showing:

- the temporary profile path;
- the intended remote and hostname;
- the framework source and pinned revision;
- an unchanged `flake.lock`;
- `Activation: not performed`.

Confirm the temporary clone stayed clean:

```bash
git -C "$rehearsal_root/dotfiles-private" status --short
```

That command should print nothing. Do not add `--activate` during a rehearsal
on the existing Mac. Remove the temporary rehearsal directory after reviewing
its path and contents.

## 7. Keep the backup current

After any intentional profile change:

```bash
cd ~/dotfiles-private
git status --short
git diff
dot secrets "$PWD"
git add <reviewed-paths>
git diff --cached
git commit -m "chore: update private profile"
git push
git log --oneline '@{upstream}..HEAD'
```

The final log should print nothing. `dot scan-unmapped` also reports
uncommitted changes, unpushed commits, or a missing remote as **AT RISK**.

## Recovery credential checklist

The Git backup is useful only if a replacement Mac can reach it. Keep these
outside the private repository:

- Git-host account recovery codes;
- the password-manager credentials needed to recover access;
- SSH key recovery or a documented process for registering a new key;
- FileVault recovery information;
- Apple Account and Mac App Store access.

Test account recovery independently of the dotfiles profile.
