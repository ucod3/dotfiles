# Operations

Day-two guide: applying changes, updating, rolling back, and recovering.
For first-run setup see [GETTING-STARTED.md](../GETTING-STARTED.md).

## Applying changes

```bash
dot rebuild
```

Resolves your private flake first, then this repo, and switches to
`darwinConfigurations.$(hostname -s)`. It runs with `--impure` so the gitignored
`.local/` layer is readable (ADR-004).

**Changes must be staged.** `git+file:` evaluation reads a dirty working tree's
*staged* changes but skips untracked files entirely, so a new file that is not
`git add`ed is silently invisible to the build.

## Updating

```bash
dot update              # flake inputs + Homebrew, then rebuild
dot update --dry-run    # preview without changing anything
dot update --flake-only # inputs only, skip the rebuild
dot update --auto       # no prompts (CI-friendly)
```

When you use a private host flake, its `dotfiles` input is what pins this repo.
`dot rebuild` re-locks it automatically when it notices your local `HEAD` has
moved ahead of the lock.

## Managing apps

```bash
dot apps list            # everything currently declared
dot apps search firefox  # find the right package name
dot apps add ghostty     # add to .local/apps.nix
dot apps remove ghostty
```

`dot apps` owns `.local/apps.nix` exclusively — it is generated and rewritten
wholesale, so do not hand-edit it. Hand-written selections belong in
`.local/settings.nix`. Apps that come from a framework example set cannot be
removed this way; disable or override the set in `.local/settings.nix` instead.

Whether removal actually uninstalls anything depends on `homebrew.cleanup`,
which is `"none"` unless you opted in.

## Adopting unmanaged files

Bringing a file that already exists in `$HOME` under declarative management.

```bash
dot scan-unmapped                   # what is adoptable
dot adopt ~/.claude/CLAUDE.md --dry-run
dot adopt ~/.claude/CLAUDE.md
dot rebuild
```

Adoption **moves** the file to `~/dotfiles-private/home/<rel>`, appends a
mapping to `~/dotfiles-private/home.nix`, and stages both. Nothing is written
to this repo, and nothing is committed for you.

```nix
home.file.".claude/CLAUDE.md".source = ./home/.claude/CLAUDE.md;
```

The source is a **path literal**, not an interpolated string. The literal is
copied into the store as part of the flake source, so it evaluates purely and
reproduces on another machine; an absolute-path string would make Home Manager
call `builtins.path` on a context-free string — an impure read that only
resolves under `--impure` and is invisible to git.

Two consequences worth internalising:

- **Between the adopt and the rebuild, the path does not exist.** The file has
  moved and Home Manager has not yet recreated it. Rebuild promptly.
- **The deployed file is read-only**, because it is a `/nix/store` symlink.
  Edit the copy under `~/dotfiles-private/home/` and rebuild. Editing in place
  is not possible, by design.

`home.nix` only applies if a host module imports it. `dot adopt` warns when
nothing does:

```nix
users.${user}.imports = [
  inputs.dotfiles.darwinModules.homeEnvironment
  ../home.nix
];
```

### What adoption refuses

Credential paths (`.ssh`, `.gnupg`, `.aws`, `.config/gh`, `.claude.json`) are
refused outright — committing them to any git repo writes them into history
permanently.

The subtler refusal is **any directory Home Manager already owns files inside**.
HM writes per-file symlinks into real directories:

```
~/.config/nvim/          real directory
├── init.lua        →    /nix/store/…-home-manager-files/…   managed
└── lazy-lock.json                                           unmanaged
```

Adopting `~/.config/nvim` would move that store symlink into the private repo
and hand the path two owners. `scan-unmapped` reports these as *partially
managed*; adopt the individual unmanaged file instead.

## Rolling back

### Nix generations

Every rebuild creates a generation. This is the real undo.

```bash
darwin-rebuild --list-generations              # what's available
sudo darwin-rebuild --rollback                 # previous generation
sudo darwin-rebuild --switch-generation 42     # a specific one

home-manager generations                       # Home Manager equivalents
```

Pruning old ones:

```bash
sudo nix-collect-garbage --delete-older-than 30d
nix-collect-garbage --delete-older-than 30d    # user profile
```

### Configuration

`git checkout -- <file>` reverts a file, but **does not change your running
system** — you must `dot rebuild` afterward, or roll back the generation. The
two are independent.

```bash
git log --oneline -10
git diff HEAD~1                    # what changed last commit
git checkout HEAD -- hosts/default.nix
git revert <sha>                   # safe: adds a new commit
dot rebuild
```

Uncommitted work you want to park:

```bash
git stash && git stash list && git stash pop
```

### Rebuilding from an older commit

```bash
git checkout <sha>
dot rebuild
git checkout main    # when you're done
```

## Backups

**What matters is `.local/`** — your identity, selections, and toggles. It is
gitignored, so it is *not* covered by pushing this repo. Back it up either by
pointing it at a private git repo or a cloud-synced folder; both are described
in [GETTING-STARTED.md](../GETTING-STARTED.md#backing-it-up).

Everything else is reproducible from the flake: the repo plus `flake.lock` plus
your private host flake fully determines the system.

Home Manager writes `*.hm-backup` files when it would otherwise clobber
something it does not manage. If activation fails complaining about an existing
file, that is what to look for.

## Secrets

```bash
dot secrets      # scan the working tree
dot hooks        # (re)install the pre-commit hook
```

The pre-commit hook runs `dot validate --quick` plus gitleaks and fails closed.
Do not weaken it to make a commit pass. Note that a clean gitleaks result only
means something if rules actually loaded — `.gitleaks.toml` must carry
`[extend] useDefault = true` (ADR-006).

Emergency bypass, for genuine emergencies: `git commit --no-verify`.

## When a rebuild fails

1. Read the actual error — nix-darwin's messages name the failing option.
2. `dot validate` for syntax and common mistakes; `nix flake check` for
   evaluation.
3. Files nix-darwin refuses to clobber (`/etc/nix/nix.conf`, `/etc/zshrc`, …)
   are the most common fresh-machine failure. `scripts/bin/bootstrap` detects
   them and prints the fix.
4. Still broken? `sudo darwin-rebuild --rollback` puts you back on the last
   working generation while you investigate.
