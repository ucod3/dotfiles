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
├── flake.nix           imports dotfiles as a git input, defines your host
└── hosts/<hostname>.nix   sets `user = "<macos-username>"`
```

The private flake consumes the shared repo as a `git+file://` input, so it
always builds against your **committed** `~/dotfiles` state.

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

Run `./scripts/bin/setup-private-host` on that machine too — it uses the
local hostname/username automatically. Each machine gets its own entry in
`~/dotfiles-private/hosts/`.

If the flake already exists but lacks an entry for the current hostname — which
also happens when macOS renames a machine on a new network — the script writes
`hosts/<name>.nix` and prints the `darwinConfigurations` block to paste in. It
deliberately does not rewrite your private `flake.nix`; that file is yours.

```bash
./scripts/bin/setup-private-host --host "$(hostname -s)"
```

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
