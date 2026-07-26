# Private Host Configuration

This repository is a shared, reusable framework. It intentionally contains
**no hostname, no macOS username, and no per-machine identity** so it stays
safe to publish and easy for anyone to reuse.

Building an actual macOS system with `nix-darwin` requires a concrete
username and hostname (for `system.primaryUser`, Home Manager, and
Homebrew). That identity lives in a separate, private, local flake:
`~/dotfiles-private`.

## Architecture

```
~/dotfiles              (this repo — shared, public-ready)
├── flake.nix           exports darwinModules.{coreSystem,homeEnvironment}
├── hosts/default.nix   shared system config (needs `user` arg)
└── nix/home/home.nix   shared Home Manager config

~/dotfiles-private       (private, local-only, not published)
├── flake.nix           imports dotfiles as a git input; enumerates ./hosts
├── home.nix            home.file mappings written by `dot adopt`
└── hosts/<hostname>.nix   one file per Mac; sets `user = "<macos-username>"`
```

The private flake consumes the shared repo as a **published** input —
`github:OWNER/REPO`, pinned to an exact revision in its `flake.lock`. Your live
system therefore builds only from what you have pushed; a local branch or an
uncommitted edit cannot reach it (ADR-009).

**It must be your fork.** `setup-private-host` reads the owner from your own
`origin` remote, and when that owner is the upstream framework it says so and
asks for your fork instead — pinning upstream gives you a Mac that rebuilds from
a repository you cannot push to (ADR-010). Override with `--fork OWNER/REPO` or
`$DOTFILES_FORK`. It falls back to `git+file://` only when there is no GitHub
remote at all.

Use `dot rebuild --override-local` to test local work without publishing it.
That path evaluates your working tree's **staged** changes; untracked files stay
invisible, so `git add` first (R2).

## Setting up a new machine

```bash
cd ~/dotfiles
./scripts/bin/setup-private-host
```

This generates `~/dotfiles-private` with a host file matching your current
`hostname -s` and `id -un`. It is safe to run once; it will not overwrite
an existing private configuration.

## Rebuilding

```bash
dot rebuild
```

`scripts/bin/rebuild` automatically detects `~/dotfiles-private` and builds
from it when your hostname is defined there. If no private configuration
exists yet, it tells you to run `setup-private-host`.

## Adding a second machine

Push `~/dotfiles-private` to a private repo (see below), clone it on the new
Mac, and run:

```bash
cd ~/dotfiles && ./scripts/bin/setup-private-host
```

It uses the local hostname and username automatically, writes
`hosts/<hostname>.nix`, and stages it. **There is nothing to edit**: the
generated `flake.nix` builds `darwinConfigurations` from `builtins.readDir
./hosts`, so a new file in that directory is a new machine (ADR-010).

The same applies when macOS renames a machine on a new network and `dot rebuild`
reports no configuration for the new hostname:

```bash
./scripts/bin/setup-private-host --host "$(hostname -s)"
```

Because `readDir` treats every `.nix` file in `hosts/` as a host, keep other
modules out of that directory.

A private flake generated before this layout existed names one host inline. The
script detects that, still writes the host file, and prints the
`darwinConfigurations` block for you to paste — it will not rewrite a flake it
did not generate.

## What the host file wires up

The generated `hosts/<hostname>.nix` imports Home Manager modules as a **list**:

```nix
users.${user}.imports = [
  inputs.dotfiles.darwinModules.homeEnvironment
  ../home.nix
];
```

`../home.nix` is where `dot adopt` writes the mappings for files it moves out of
`$HOME`. `setup-private-host` creates it up front — empty but valid — so the
first adoption deploys without you editing the host file. Add your own modules to
that list the same way.

## Manual setup & customization

If you prefer to write the private flake by hand — or want to disable the
upstream author's application sets (`dotfiles.apps.<set>.enable = false;`)
and add per-machine overrides — start from the fully documented template at
`hosts/_template.nix`. The optional app-set modules live in
`nix/modules/apps/`.

## Backing up the private configuration

`~/dotfiles-private` is a normal git repository. To back it up, create a
**private** GitHub repository and push to it:

```bash
gh repo create dotfiles-private --private
cd ~/dotfiles-private
git remote add origin git@github.com:<you>/dotfiles-private.git
git push -u origin main
```

Never make this repository public — it contains your macOS username and
hostname.
