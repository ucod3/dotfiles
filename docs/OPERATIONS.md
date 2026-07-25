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
