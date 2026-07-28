# Architecture and Ownership

[`PRODUCT.md`](./PRODUCT.md) defines the product contract. This document
explains which repository and configuration layer owns each part of the system.

## Repository boundary

```text
ucod3/dotfiles
    reusable framework, modules, commands, templates, tests
            │
            │ selected and pinned by flake.nix + flake.lock
            ▼
~/dotfiles-private
    identity, hosts, apps, preferences, adopted files
            │
            │ evaluated as darwinConfigurations.<hostname>
            ▼
macOS + user environment
```

The public framework contains no user's hostname, username, application choices,
adopted files, or personal preferences. The private profile is the complete
user-owned definition of the Mac.

Ordinary profiles select:

```nix
inputs.dotfiles.url = "github:ucod3/dotfiles";
```

The private `flake.lock` records the exact framework revision. A compatible
framework fork is an advanced override, not an installation requirement.

## Configuration layers

### nix-darwin

Owns system-level macOS configuration:

- `environment.systemPackages`;
- `system.defaults` and system services;
- Homebrew declarations exposed through nix-darwin;
- system activation and generations;
- wiring Home Manager to each declared user.

The public framework exports reusable nix-darwin modules. The private host
imports those modules and the user's focused private modules.

### nix-homebrew and native Homebrew

`nix-homebrew` installs or adopts the Homebrew installation and manages its
prefix integration. nix-darwin supplies the declared formulae, casks, and Mac
App Store applications during activation.

Homebrew is normally used for:

- macOS `.app` bundles;
- proprietary or platform-native software;
- packages unavailable or unsuitable in Nixpkgs;
- the `mas` command used for App Store declarations.

Home Manager does not install or own Homebrew.

### Home Manager

Owns user-space packages and configuration:

- shell configuration and environment variables;
- program modules such as Git, Neovim, and Zsh;
- `home.packages`;
- `xdg.configFile` and `home.file` mappings;
- adopted files imported from the private profile.

Use `xdg.configFile` only for software that reads XDG paths. Native macOS apps
such as editors usually read `~/Library/Application Support/...` and must use a
matching `home.file` path.

### Private profile

New profiles group user choices by responsibility:

```text
dotfiles-private/
├── hosts/                  one module per Mac
├── apps/                   casks, Nix packages, and App Store apps
├── macos/                  personal macOS preferences
├── home/                   Home Manager choices and adopted file storage
├── home.nix                generated adopted-file mappings
├── identity.nix            profile-owned Git identity
├── flake.nix               composition and framework selection
└── flake.lock              exact framework and dependency revisions
```

Each value has one obvious private source of truth. Public modules implement and
validate those choices.

## Application flow

```text
apps/homebrew-casks.nix ───────► homebrew.casks
apps/mac-app-store.nix ────────► homebrew.masApps
apps/nix-packages.nix ─────────► environment.systemPackages
```

`dot apps` edits only generated plain-list files. If an advanced user replaces a
file with a composed Nix expression, the helper refuses to parse or rewrite it.

Package preference:

1. Use Nixpkgs for portable command-line tools when the package works on Darwin.
2. Use nix-darwin system packages for tools intended for the whole configured
   system.
3. Use Home Manager packages for tools owned by a specific user module.
4. Use Homebrew casks for native Mac applications and platform-specific tools.

Never declare the same package in two layers merely for convenience.

## Adopted files

`dot adopt <path>` moves an existing home path into the private profile and adds
a Home Manager mapping. The default mapping deploys a read-only Nix-store
symlink. `--mutable` creates an out-of-store link for applications that must
continue writing the file.

Do not add public framework cases for personal application settings. Adopt the
specific portable files instead. Credentials, histories, caches, sessions, and
machine-local state are not adoption candidates.

## Evaluation and activation

- Normal rebuilds use the framework revision pinned by the private lock.
- Restore preserves the committed lock.
- Local framework experiments require an explicit override.
- New files must be staged before `git+file:` evaluation can see them (R2).
- Preflight reports profile, host, framework, and lock without switching.
- Activation is separate and requires explicit confirmation.

## Legacy `.local/` compatibility

Existing installations may still expose private settings through
`~/dotfiles/.local`, often as a symlink to `~/dotfiles-private`. This is a
supported compatibility path, not the structure generated for new profiles.

The bridge has verified constraints:

- `lib/local.nix` is the only sanctioned `builtins.getEnv` exception (R3).
- Rebuild forwards `DOTFILES_LOCAL` through the sudo boundary and evaluates
  with `--impure`.
- A directory counts as a legacy settings layer only when it contains a
  recognized settings file; presence alone is not consent.
- `.local/hosts/` must not be imported by the legacy loader because the private
  flake already owns hosts.
- Both single-line and multiline legacy app lists remain supported.

Do not remove or simplify this bridge until the roadmap's migration phase proves
equivalence for existing profiles (R4).

## Architectural safety rules

- Never place private values in the public framework (R1).
- Never make destructive Homebrew cleanup the default (R5).
- Never derive behavior from the mere presence of a directory.
- Never silently update a private lock during restore or rebuild.
- Never select another host when the requested hostname is unknown.
- Never write irreversible files from shell startup or declarative activation.
- Never replace ordinary Nix with a hidden second configuration format.
