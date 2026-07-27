# macOS Dotfiles

**What this does:** you write down which apps you want and which config files
matter to you. One command makes any Mac match that. Wipe the machine, buy a
new one, run the command — you get your setup back.

That's it. Three ideas:

**1. A list of what you want.** One file, `settings.nix`, names your apps:

```nix
casks = [ "firefox" "ghostty" ];
```

Add a line, run `dot rebuild`, the app installs. Delete the line, it's removed.
No clicking through installers, no remembering what you had.

**2. Your config files, kept in a git repo.**

```bash
dot adopt ~/.config/zed/settings.json --mutable
```

That moves the real file into `~/dotfiles-private` and leaves a link behind.
Zed still finds it and you still edit it normally — but now it has history and
travels to your next Mac.

**3. One command to apply it all:** `dot rebuild`.

### Am I actually backed up?

```bash
dot scan-unmapped
```

It tells you, in plain terms, what would be lost if this Mac died — and it
looks in `~/Library/Application Support`, where macOS apps really keep their
settings. It will not offer you extension folders or anything holding a
credential, and it prints its reasoning so you can disagree with it.

**Adopting a file is only half of it.** Adopted files live in
`~/dotfiles-private`, which is a git repo on the same disk as the files it
protects — so it is not a backup until it has been pushed. `dot promote` now
publishes it for you (after scanning it for secrets), and `dot scan-unmapped`
says **AT RISK**, with the commit count, whenever it has not happened.

**What it will never restore:** SSH keys, app logins, licence keys. Those
belong in a password manager or Time Machine. Anything claiming otherwise is
setting you up to lose them.

**The framework names no application.** There is no bundled browser, editor,
terminal or window manager anywhere in this repo — not as a default, not behind
a toggle. Fork it and you get your choices, not the author's.

Apple Silicon only.

---

Underneath, this is Nix flakes, nix-darwin, Home Manager, nix-homebrew and
native Homebrew. You do not need to understand any of that to use it, and the
rest of this file is written for when you do.

## Install

**Fork this repository first.** Your fork is what your Mac rebuilds from, and
it is the only place you can push changes to — the installer asks for it, and
pinning upstream instead leaves you unable to promote your own work.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh)
# non-interactive:
bash <(curl -fsSL .../install.sh) --repo YOU/dotfiles
```

The installer checks prerequisites (Xcode CLT, Nix, Rosetta), asks what you
want, generates your private host flake pinned to *your* fork, and runs the
first build.

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
dot promote            # ship it: validate, push, bump the pin, rebuild
dot update             # update flake inputs + Homebrew, then rebuild
dot apps add ghostty   # add an app to your selections
dot apps list          # see what's declared
dot adopt ~/.foorc     # bring an existing config under management
dot validate           # syntax + common-mistake checks
dot secrets            # scan for leaked secrets
dot help               # full reference
```

`rebuild`, `promote`, `update`, `validate` and `apps` are also available as bare
aliases.

### More than one Mac

Push `~/dotfiles-private` to a private repo, clone it on the second machine, and
run `./scripts/bin/setup-private-host`. It adds `hosts/<that-hostname>.nix` and
the private flake picks it up automatically — there is no flake to hand-edit.

## Turning things on

Everything opinionated is off until you ask. Edit `.local/settings.nix` and run
`dot rebuild`:

```nix
{
  ai.enable = true;                     # AI editor config symlinks

  homebrew.cleanup = "uninstall";       # prune casks you no longer declare
  system.macosDefaults.enable = true;   # Dock/Finder/key-repeat profile
  home.exampleProfile.enable = true;    # the whole example home profile at once
                                        # (oh-my-zsh, ghostty, vscode/cursor,
                                        #  node tooling, personal aliases,
                                        #  zoxide-as-cd, git workflow, workshop)

  # Your applications. This list is the whole of what gets installed.
  casks = [ "firefox" "ghostty" "rectangle" ];  # https://formulae.brew.sh/cask/
  nixPackages = [ "htop" ];                     # https://search.nixos.org/packages
  masApps = { Notability = 360593530; };        # App Store → Copy Link → number
}
```

With `homebrew.cleanup = "uninstall"`, that cask list is authoritative:
anything you installed by hand and did not list is removed on the next rebuild.

Each home toggle can also be set individually from your private host file
instead of all at once — see [`hosts/_template.nix`](./hosts/_template.nix),
the complete worked example.

## Where do I put things?

| What | Where | Notes |
|---|---|---|
| Apps, packages, App Store items | `.local/settings.nix` | `casks` / `nixPackages` / `masApps` |
| Your aliases, functions, `PATH` | `config/zsh/custom.local.zsh` | Unmanaged and untracked — yours alone |
| Git name and email | `.local/identity.nix` | |
| A `$HOME` config file you want versioned | `dot adopt ~/path` | Moves it into the private flake and symlinks it back |
| …one the app rewrites itself (editor `settings.json`) | `dot adopt ~/path --mutable` | Same, but the file stays **writable** — the app keeps saving, straight into your repo |
| What is *not* yet versioned | `dot scan-unmapped` | Lists adoption candidates |
| Hostname / username | `.local/hosts/<host>.nix` | Written by `setup-private-host` |

`.local/` is a symlink to your private repo, so everything above is versioned
there and travels to your next Mac — while the public repo stays generic.

> **Nothing here defaults to destructive, and nothing redefines your commands.**
> `homebrew.cleanup` stays `"none"` until you opt in, and a build that would
> prune against an empty cask list refuses to evaluate (ADR-007). A cold fork's
> shell leaves `cd`, `npm` and `git pull` alone, and touches no project you
> `cd` into (ADR-011).

## Making it yours

| You want to… | Do this |
|---|---|
| Add aliases, exports, tool setup | `cp config/zsh/custom.local.zsh.example config/zsh/custom.local.zsh` — gitignored, sourced last, never clobbered by a rebuild |
| Install an app | `dot apps add <name>`, or add it to `.local/settings.nix` |
| Bring an existing config under management | `dot adopt ~/.config/whatever` — it moves into your private flake |
| Ship a change to your Mac | `dot promote` |

The framework installs applications and owns a few core configs (git, Neovim,
zsh, optionally VS Code/Cursor and Ghostty). Everything else that lives in your
`$HOME` is `dot adopt`'s job, not this repo's.

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

MIT — see [LICENSE](./LICENSE).
