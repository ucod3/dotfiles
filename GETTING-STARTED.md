# Getting Started

A universal, de-opinionated macOS environment template. A fresh install
ships shell, Neovim, and core CLI tooling — **no opinionated GUI apps** —
and asks you what you actually want.

## 1. Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh)
```

The installer walks you through:
1. System prerequisites (Xcode CLT, Nix, Rosetta).
2. **Your choices** — browsers, editors, terminal, window manager — via
   select menus. Selections are written to the gitignored `.local/` layer.
3. A private host flake (`~/dotfiles-private`) holding your hostname and
   username, generated automatically.
4. The first system build.

## 2. Managing Your Local Settings (`.local/`)

Everything personal — your name/email, app selections, and host identity — lives
in `~/dotfiles/.local/`. This directory is **gitignored by default** so that
private information never leaks into the public `dotfiles` repository. The
installer creates it interactively, but you choose how it is backed up and synced.

```
.local/
├── identity.nix          # { name = "..."; email = "..."; }  → git identity
├── settings.nix          # toggles + flat app selections
├── browsers/choices.nix  # { casks = [...]; nixPackages = [...]; }
├── editors/choices.nix
└── hosts/                # reserved for your private flake
```

### Path A: Private GitHub repository (recommended for multi-machine sync)

Create a private repository to back your `.local/` layer and keep multiple Macs
in sync:

1. If you already have a `~/dotfiles-private` repository, the installer symlinks
   `.local -> ~/dotfiles-private` automatically.
2. Otherwise, scaffold a new private flake and move your local settings into it:

```bash
cd ~/dotfiles
./scripts/bin/setup-private-host

# Migrate existing .local/ files into the private repo and replace .local with the symlink
mv ~/dotfiles/.local/* ~/dotfiles-private/ && rmdir ~/dotfiles/.local
ln -s ~/dotfiles-private ~/dotfiles/.local
```

3. Create a private GitHub repository and push:

```bash
gh repo create dotfiles-private --private
cd ~/dotfiles-private
git remote add origin git@github.com:<you>/dotfiles-private.git
git push -u origin main
```

On a new machine, clone your private repo and link it before rebuilding:

```bash
git clone git@github.com:<you>/dotfiles-private.git ~/dotfiles-private
ln -s ~/dotfiles-private ~/dotfiles/.local
cd ~/dotfiles && dot rebuild
```

### Path B: Simple cloud backup (single machine)

If you only use one Mac and prefer not to maintain a second Git repository, move
`.local/` to a cloud-synced folder and symlink it back:

```bash
# Example: iCloud Drive
CLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-local"
mv ~/dotfiles/.local "$CLOUD_DIR"
ln -s "$CLOUD_DIR" ~/dotfiles/.local
```

This works with iCloud Drive, Dropbox, Google Drive, or any other synced folder.
Your settings stay backed up and off GitHub entirely.

> Note: `dot rebuild` runs with `--impure` so the gitignored `.local/`
> layer is readable — see `AGENTS.md` and `docs/DECISIONS.md` (ADR-004) for the why.

## 3. Enabling more

Edit `.local/settings.nix` and run `dot rebuild`:

```nix
{
  ai.enable = true;                    # Devin Desktop + AI editor configs
  apps.browsers.enable = true;         # example app sets (see nix/modules/apps/)
  casks = [ "ghostty" "rectangle" ];   # any Homebrew casks
  nixPackages = [ "htop" ];            # any Nixpkgs attributes
}
```

Every app set under `nix/modules/apps/` is **opt-in** and fully overridable
(`dotfiles.apps.<set>.casks = [ ... ];`). Look for `# CUSTOMIZE:` comments
throughout the tree. `hosts/_template.nix` is the complete example profile.

## 4. Daily driving

```bash
dot rebuild    # apply configuration changes
dot update     # update flake inputs + Homebrew, then rebuild
dot apps add firefox
dot validate   # syntax + common-mistake checks
```

> Note: `dot rebuild` runs with `--impure` so the gitignored `.local/`
> layer is readable — see `AGENTS.md` for the why.
