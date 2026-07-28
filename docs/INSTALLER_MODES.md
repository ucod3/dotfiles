# Installer profile journeys

`setup.sh` is the safe public entry point for a clean Mac. It asks one question
up front:

1. Create a new private profile.
2. Restore an existing private profile.

The two journeys share discovery and prerequisites, but they do not share profile
mutation logic. New-profile generation belongs to the framework. Restore belongs
to the cloned private profile through its own `./bootstrap` entry point.

## Interactive use

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh)
```

The process-substitution form keeps standard input connected to the terminal so
the menu and any later confirmation prompts can read user input.

## Create a new profile

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --new
```

The new journey:

1. Verifies macOS, Xcode Command Line Tools, Git, and Nix.
2. Resolves an author identity for the private profile's local Git commits.
3. Clones the framework into `~/dotfiles`.
4. Uses `setup-private-host` to generate the readable modular profile at
   `~/dotfiles-private`.
5. Creates and commits the initial `flake.lock`.
6. Offers application selection through the focused private `apps/` files.
7. Commits reviewed application choices locally.
8. Runs the generated profile's `./bootstrap` in preflight mode.

The generated profile is a local Git repository, not a backup. The installer
prints a warning until the owner creates a private remote and pushes it.

### Git identity

Git records an author name and email on the profile's initial commits. If both
already exist in the owner's global Git configuration, the installer reuses
them without changing anything.

When either value is missing, interactive setup explains why it is needed and
asks for both values. Those answers are saved only in
`~/dotfiles-private/.git/config`; the installer does not write global Git
settings.

Non-interactive setup can provide the standard Git environment variables:

```bash
GIT_AUTHOR_NAME="Example User" \
GIT_AUTHOR_EMAIL="YOUR_GIT_EMAIL" \
bash setup.sh --new --skip-apps
```

The values are used for the generated commits and then saved only in that
private repository. Restore mode never asks for or changes Git identity.

### Choose applications

In an interactive terminal, a new-profile setup asks whether to configure
applications. The owner can repeatedly choose:

1. Homebrew cask
2. Nix package
3. Mac App Store application
4. Finish

The installer delegates each choice to the same profile-aware `dot apps`
implementation used after installation. It does not maintain a separate catalog
or application format.

For a repeatable non-interactive setup, pass selections explicitly:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --new \
  --cask firefox \
  --cask ghostty \
  --nix-package ripgrep \
  --mas-app "Notability=360593530"
```

Each flag is repeatable. `--skip-apps` explicitly keeps the generated lists
empty and suppresses the interactive question.

Application changes are shown with `git diff`, staged from `apps/`, and saved in
a local `Choose applications` commit before profile preflight. If any selection
fails, all `apps/` files are restored to the generated commit and preflight does
not run.

These options are rejected during `--restore`. Restoration preserves the
profile's committed choices byte-for-byte.

The default command does not activate nix-darwin. Activation must be requested
explicitly:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- --new --activate
```

The profile-owned restore command still prints the exact activation plan and
requires its hostname confirmation.

## Restore an existing profile

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git
```

The restore journey:

1. Verifies macOS, Xcode Command Line Tools, and Git.
2. Clones only the private profile into `~/dotfiles-private`.
3. Requires `flake.nix`, committed `flake.lock`, and `bootstrap`.
4. Invokes `./bootstrap --host "$(hostname -s)"`.

It does **not** clone a separate framework checkout, ask application or identity
questions, regenerate settings, select a fallback hostname, or update
`flake.lock`. The profile's committed framework pin supplies the restore engine.

To activate after reviewing the restore contract:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git \
  --activate
```

For deliberately unattended recovery only, `--yes` can accompany
`--activate`. It is rejected on its own.

## Existing directories

The installer refuses an existing framework or private-profile destination. It
does not rename, delete, merge, or back up an existing checkout automatically.
The owner must inspect and resolve the collision deliberately.

Alternative locations are explicit:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git \
  --profile-dir "$HOME/my-private-profile"
```

## Compatibility

The older top-level `install.sh` remains available during this transition for
its existing create-and-build workflow. New documentation and clean-machine
validation should use `setup.sh`, whose default is preflight rather than live
activation.
