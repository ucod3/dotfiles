# macOS Dotfiles

A declarative, reproducible macOS environment built on Nix flakes, nix-darwin,
Home Manager, nix-homebrew, and native Homebrew.

**It is de-opinionated.** The framework core installs no GUI apps and changes no
macOS settings. Shell, Neovim, and core CLI tooling come as standard; everything
else — browsers, editors, terminal, window manager, macOS defaults — is opt-in
and asked for at install time. Fork it and you get a working system that looks
like *your* choices, not the author's.

Apple Silicon only.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh)
```

The installer checks prerequisites (Xcode CLT, Nix, Rosetta), asks what you
want, generates your private host flake, and runs the first build.

Already cloned by hand? Run `./scripts/bin/bootstrap` — it is idempotent and
handles the same first-run concerns.

See [GETTING-STARTED.md](./GETTING-STARTED.md) for the full walkthrough,
including what to do when the first build fails.

## The three layers

Know which one owns a change before you make it.

| Layer | Path | Contents |
|---|---|---|
| Public framework | `~/dotfiles` | This repo. Generic, safe to distribute. |
| Private identity | `~/dotfiles-private` | Your hostname and username, as a downstream flake. Generated for you. |
| Machine-local | `.local/` (gitignored) | Your name/email, app selections, opt-in toggles. |

This repo ships `darwinConfigurations = { }` **on purpose**: a host needs a
concrete hostname and username, which a public framework must not hardcode.
That is what the private flake is for — see
[docs/PRIVATE_HOST_SETUP.md](./docs/PRIVATE_HOST_SETUP.md).

## Daily use

```bash
dot rebuild            # apply configuration changes
dot update             # update flake inputs + Homebrew, then rebuild
dot apps add ghostty   # add an app to your selections
dot apps list          # see what's declared
dot validate           # syntax + common-mistake checks
dot secrets            # scan for leaked secrets
dot help               # full reference
```

`rebuild`, `update`, `validate` and `apps` are also available as bare aliases.

## Turning things on

Everything opinionated is off until you ask. Edit `.local/settings.nix` and run
`dot rebuild`:

```nix
{
  ai.enable = true;                     # AI tooling configs
  apps.browsers.enable = true;          # example app sets — see nix/modules/apps/
  apps.development.enable = true;

  homebrew.cleanup = "uninstall";       # prune casks you no longer declare
  system.macosDefaults.enable = true;   # Dock/Finder/key-repeat profile
  home.exampleProfile.enable = true;    # oh-my-zsh, ghostty, vscode, node tooling

  casks = [ "ghostty" "rectangle" ];    # any Homebrew casks
  nixPackages = [ "htop" ];             # any nixpkgs attributes
}
```

Each app set is fully overridable (`dotfiles.apps.<set>.casks = [ ... ];`).
Look for `# CUSTOMIZE:` comments throughout the tree.
[`hosts/_template.nix`](./hosts/_template.nix) is the complete worked example.

> **Nothing here defaults to destructive.** `homebrew.cleanup` stays `"none"`
> until you opt in, and a build that would prune against an empty cask list
> refuses to evaluate. See ADR-007.

## Documentation

| Doc | Covers |
|---|---|
| [GETTING-STARTED.md](./GETTING-STARTED.md) | Install, `.local/` schema, first-run troubleshooting |
| [docs/OPERATIONS.md](./docs/OPERATIONS.md) | Day-to-day: updates, rollback, generations, backups |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Which layer owns which package or setting |
| [docs/DECISIONS.md](./docs/DECISIONS.md) | ADRs — read before reversing anything deliberate |
| [docs/TESTING.md](./docs/TESTING.md) | `dot validate`, the bats suite, CI |
| [docs/PRIVATE_HOST_SETUP.md](./docs/PRIVATE_HOST_SETUP.md) | The downstream private flake |
| [AGENTS.md](./AGENTS.md) | The contract for AI agents working in this repo |

## Repository layout

```
flake.nix              Inputs, exported modules, evaluation checks
hosts/                 System-level config (default.nix) + downstream template
nix/modules/           Opt-in app sets, Homebrew policy, macOS defaults
nix/home/              Home Manager configuration
lib/                   Nix helpers (local.nix, pkgs.nix) + shell helpers
config/                Dotfiles proper: zsh, git, nvim, ghostty, editors
scripts/bin/           The `dot` CLI and its subcommands
tests/                 bats suite
docs/                  Architecture, decisions, operations, testing
```

## Working with AI agents

The agent contract is vendor-neutral and lives in [AGENTS.md](./AGENTS.md).
Claude, Cursor, Copilot, Devin and Windsurf each have a short pointer file that
restates nothing, so any tool — including one with no config here at all — gets
the same rules. See ADR-008.

## License

MIT
