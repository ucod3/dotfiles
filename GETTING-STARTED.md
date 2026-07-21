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

## 2. The `.local/` settings layer

Everything personal lives in `~/dotfiles/.local/` (gitignored):

```
.local/
├── identity.nix          # { name = "..."; email = "..."; }  → git identity
├── settings.nix          # toggles + flat app selections
├── browsers/choices.nix  # { casks = [...]; nixPackages = [...]; }
├── editors/choices.nix
└── hosts/                # reserved for your private flake
```

If `~/dotfiles-private` already exists, the installer just symlinks
`.local -> ~/dotfiles-private` so the private repo is the backing storage.
You can adopt that layout at any time:

```bash
mv ~/dotfiles/.local/* ~/dotfiles-private/ && rmdir ~/dotfiles/.local
ln -s ~/dotfiles-private ~/dotfiles/.local
```

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
