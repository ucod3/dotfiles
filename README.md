# ucod3's Dotfiles

This repo is the source of truth for your macOS setup:

- `nix-homebrew` manages the Homebrew installation itself
- `nix-darwin` manages Homebrew brews, casks, and `mas` apps declaratively
- Home Manager manages user-level config files and shell setup
- helper scripts live under `scripts/bin`

## Bootstrap on a New Mac

1. Install Nix and get `darwin-rebuild` working.
2. Clone this repo to `~/dotfiles`.
3. Rebuild from the flake:

```sh
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
cd ~/dotfiles/nix
nix flake update
~/dotfiles/scripts/bin/rebuild
```

## Daily workflow

```sh
~/dotfiles/scripts/bin/rebuild
```

That wrapper runs `brew update`, applies the flake with `darwin-rebuild switch`, then runs `scripts/bin/check-brew-manual-installers` as your normal user.

## Zsh setup

Zsh is now managed by Home Manager from `nix/home/home.nix`.

- Oh My Zsh is enabled declaratively for the plugin layer
- `zoxide`, `fzf`, autosuggestions, syntax highlighting, and history substring search are managed declaratively
- custom shell logic stays in `config/zsh/custom.zsh`
- `config/zsh/legacy-oh-my-zsh.zsh` is kept only as a reference copy of the old hand-managed setup

If you want your exact old prompt back, add the missing custom theme file for `custom-cobalt2` into this repo and update the theme setting in `home.nix`.

## Manual Homebrew installers

Some casks ship an installer app or a caveat that still needs a human step after `brew bundle` finishes. That is why `scripts/bin/check-brew-manual-installers` exists.

Use it after a rebuild if Homebrew installed or upgraded casks:

```sh
~/dotfiles/scripts/bin/check-brew-manual-installers
```

This does **not** fix cask-definition/parser problems like the earlier Adobe Reader failure. It is only for installs or upgrades that completed but still require you to open an installer app manually.

## Adding config files

- Put reusable config under `config/`
- Map it from `nix/home/home.nix`
- Rebuild with `~/dotfiles/scripts/bin/rebuild`

Examples already wired in:

- `config/git/.gitconfig`
- `config/nvim/`
- `config/vscode/settings.json`
- `config/windsurf/config.json`
- `config/zsh/`

## Notes

- `nix/homebrew/Brewfile` has been removed on purpose. nix-darwin now generates the Brewfile from `homebrew.*`.
- `scripts/setup/bootstrap.zsh` is just a small convenience wrapper around `scripts/bin/rebuild`.
- If this is still only a local folder, run `git init`, `git add .`, and make your first commit.
