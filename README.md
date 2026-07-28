# Dotfiles Framework for macOS

Rebuild your Mac from a readable private profile instead of remembering every
application, setting, and configuration file by hand.

This repository is the reusable public framework. It contains no user's
hostname, identity, application choices, adopted files, or personal
preferences. Each user owns a separate private profile that records those
choices and pins the exact framework revision used to apply them.

Apple Silicon only. The project is still working toward its first fully proven
clean-Mac, no-AI release; see the [roadmap](./docs/ROADMAP.md).

## The two repositories

| Repository | Owns |
| --- | --- |
| `ucod3/dotfiles` | Installer, reusable Nix modules, commands, safe defaults, and documentation |
| `~/dotfiles-private` | Hosts, applications, macOS preferences, Home Manager settings, adopted files, identity, and the pinned framework revision |

Ordinary users consume this public framework directly. They do **not** need to
fork it. A fork is an advanced option for someone intentionally maintaining a
different framework.

## Start here

Run the public setup entry point:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh)
```

It offers two journeys:

1. Create a new private profile.
2. Restore an existing private profile.

The default result is a non-destructive preflight. Nothing activates the Mac
until you explicitly request activation and confirm the selected hostname.

Full walkthrough: [GETTING-STARTED.md](./GETTING-STARTED.md).

### Create a new profile

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --new
```

The installer:

- checks macOS prerequisites and installs Nix when it is missing;
- clones the public framework into `~/dotfiles`;
- generates a readable Git repository at `~/dotfiles-private`;
- optionally records applications in focused private Nix files;
- pins the exact framework revision in the private `flake.lock`;
- finishes with restore preflight unless activation was explicitly requested.

Homebrew and the selected applications are installed during activation, not
during preflight. `nix-homebrew` installs or adopts Homebrew, nix-darwin applies
Homebrew and Mac App Store declarations, and Home Manager separately manages
user packages and home configuration.

### Restore an existing profile

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/setup.sh) -- \
  --restore git@github.com:you/dotfiles-private.git
```

Restore clones only the private profile and invokes its own `./bootstrap`. It
preserves the profile's existing framework source and committed `flake.lock`.
It never reruns new-profile questions, chooses another hostname silently, or
activates without an explicit request.

A private profile can also restore itself without returning to this repository:

```bash
git clone git@github.com:you/dotfiles-private.git ~/dotfiles-private
cd ~/dotfiles-private
./bootstrap
```

## The private profile stays readable

A newly generated profile has focused responsibilities:

```text
dotfiles-private/
├── README.md
├── bootstrap
├── flake.nix
├── flake.lock
├── identity.nix
├── hosts/
├── apps/
│   ├── homebrew-casks.nix
│   ├── nix-packages.nix
│   └── mac-app-store.nix
├── macos/
└── home/
```

The files contain ordinary Nix. The `dot` commands are conveniences that print
the owning file and equivalent native operation; they do not replace Nix with a
second configuration language.

## Choose applications

Applications can be selected interactively during new-profile setup or managed
later:

```bash
dot apps list
dot apps search firefox
dot apps add firefox
dot apps add --nix ripgrep
dot apps add --mas Notability \
  "https://apps.apple.com/us/app/notability/id360593530"
git -C ~/dotfiles-private diff -- apps/
```

Search is read-only and points to official Homebrew and Nix package sources.
For an App Store application, use **Copy Link** and paste the Apple URL.

The framework declares no GUI application of its own. Removing an app
declaration does not prune software while `homebrew.cleanup` remains `"none"`,
which is the safe default.

## Adopt configuration files

Bring an existing file under private-profile management:

```bash
dot adopt ~/.config/example
```

Use `--mutable` when the application must continue writing to the file:

```bash
dot adopt ~/.config/zed/settings.json --mutable
```

Before adopting more files, audit what is already covered:

```bash
dot scan-unmapped
```

The scanner excludes known credentials, caches, histories, extension payloads,
and machine-local churn. SSH keys, app logins, licence keys, and other secrets
belong in a password manager or system backup—not in Git.

## Back up the private profile

`~/dotfiles-private` is a Git repository, but a repository on the same disk is
not yet a backup. Connect it to a private Git remote and verify every important
commit has been pushed.

The framework does not require GitHub; any private Git remote that can be cloned
on the replacement Mac can hold the profile. Provider-neutral backup guidance
is tracked as the next roadmap phase.

## Daily use

```bash
dot rebuild              # apply the private profile's pinned configuration
dot apps list             # show application declarations and owning files
dot scan-unmapped         # audit unmanaged configuration
dot adopt <path>          # bring a home path under management
dot validate              # run the full repository checks
dot secrets <path>        # scan a repository for credential material
dot help                  # complete command reference
```

Framework updates and personal changes are separate:

- the private files record what the user chose;
- `flake.lock` records which framework revision applies those choices;
- updating the framework changes the lock, not the private choices;
- restoring uses the committed lock rather than silently selecting newer code.

Follow the [operations guide](./docs/OPERATIONS.md#update-the-pinned-framework)
to review and move the private profile's framework pin deliberately.

## Existing installations

Existing profiles that still use the `.local/` compatibility layout remain
supported. They are not rewritten automatically. The planned migration is
previewed, reviewed, and performed one responsibility at a time; see the
[roadmap](./docs/ROADMAP.md#phase-4--existing-profile-migration--queued).

The older `install.sh` remains a legacy compatibility entry point during this
transition. New installations use `setup.sh`.

## Safety model

- Public code contains no user's private values.
- Destructive Homebrew cleanup is off by default.
- Restore and framework updates preserve the committed lock unless the owner
  explicitly changes it.
- Activation prints the exact host and command and requires confirmation.
- Unknown hosts stop instead of silently selecting another configuration.
- Existing destinations are never overwritten merely because they exist.
- Green tests do not replace a physical clean-Mac rehearsal.

## Documentation

| Document | Covers |
| --- | --- |
| [Product contract](./docs/PRODUCT.md) | Purpose, ownership model, design principles, and definition of success |
| [Roadmap](./docs/ROADMAP.md) | Current phase, remaining work, and v1 release gates |
| [Getting started](./GETTING-STARTED.md) | New-profile and restore walkthroughs |
| [Installer modes](./docs/INSTALLER_MODES.md) | Complete `setup.sh` arguments and safety behavior |
| [Operations](./docs/OPERATIONS.md) | Applications, updates, rebuilds, adoption, backup checks, and rollback |
| [Architecture](./docs/ARCHITECTURE.md) | Nix, nix-darwin, Home Manager, Homebrew, and profile ownership |
| [Clean-machine acceptance](./docs/CLEAN_MACHINE_ACCEPTANCE.md) | Automated, hardware, and human evidence |
| [Decisions](./docs/DECISIONS.md) | Architectural decision records |
| [Testing](./docs/TESTING.md) | Validation, Bats, flake evaluation, and CI |
| [Agent contract](./AGENTS.md) | Rules for humans and AI tools changing this repository |

## Development

Work happens on feature branches. Before declaring a change complete:

```bash
scripts/bin/dot validate
```

The suite checks shell and Nix syntax, linting, flake evaluation, regression
tests, public-repository purity, and Git tracking.

## License

[MIT](./LICENSE)
