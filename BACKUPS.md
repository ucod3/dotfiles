# Backup & Recovery Guide

This guide covers backup and recovery procedures for your Nix-based macOS dotfiles setup.

## Table of Contents

- [Git Version Control](#git-version-control)
- [Nix Configuration Rollback](#nix-configuration-rollback)
- [Home Manager State](#home-manager-state)
- [Homebrew Recovery](#homebrew-recovery)
- [Full System Recovery](#full-system-recovery)
- [Emergency Procedures](#emergency-procedures)

---

## Git Version Control

Your dotfiles are version-controlled with Git, making it easy to track and revert changes.

### View Recent Changes

```bash
cd ~/dotfiles
git log --oneline -10
```

### View Diff of Changes

```bash
# View changes in working directory
git diff

# View changes in last commit
git show HEAD

# View changes in specific file
git diff flake.nix
```

### Revert to Previous Version

```bash
# Revert specific file to last commit
git checkout HEAD -- flake.nix

# Revert to specific commit
git checkout <commit-hash> -- .

# Create a new commit that reverts a previous commit
git revert <commit-hash>
```

### Stash Uncommitted Changes

```bash
# Stash current changes
git stash

# List stashes
git stash list

# Apply stashed changes
git stash pop
```

---

## Nix Configuration Rollback

Nix maintains generations of system configurations, allowing you to roll back if a build fails or introduces issues.

### List Available Generations

```bash
# List darwin system generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# List Home Manager generations
home-manager generations
```

### Roll Back to Previous Generation

```bash
# Roll back darwin system to previous generation
sudo nix-env --switch-generation <generation-number> --profile /nix/var/nix/profiles/system
sudo darwin-rebuild switch --rollback

# Roll back Home Manager to previous generation
home-manager rollback
```

### Delete Old Generations

```bash
# Delete darwin generations older than 30 days
sudo nix-collect-garbage -d --delete-older-than 30d

# Delete Home Manager generations older than 30 days
home-manager expire-generations -30d
```

### Rebuild from Specific Git Commit

```bash
cd ~/dotfiles

# Checkout specific commit
git checkout <commit-hash>

# Rebuild from that commit
~/dotfiles/scripts/bin/rebuild
```

---

## Home Manager State

Home Manager maintains state files and backups of configuration files.

### Home Manager Backups

When Home Manager activates, it creates backups of modified files with the `.hm-backup` extension.

```bash
# Find Home Manager backups
find ~ -name "*.hm-backup"

# Restore a specific backup
cp ~/.config/git/config.hm-backup ~/.config/git/config
```

### Home Manager State Directory

Home Manager state is stored in `~/.local/state/home-manager/`. If you need to reset Home Manager:

```bash
# Backup current state
mv ~/.local/state/home-manager ~/.local/state/home-manager.backup

# Rebuild to regenerate state
cd ~/dotfiles
~/dotfiles/scripts/bin/rebuild
```

---

## Homebrew Recovery

Homebrew packages are managed through Nix, but you can interact with Homebrew directly if needed.

### List Installed Packages

```bash
# List all installed formulae
brew list

# List all installed casks
brew list --cask

# View Brewfile
cat /opt/homebrew/Library/Taps/homebrew/homebrew-core/.../Brewfile
```

### Reinstall from Brewfile

```bash
cd ~/dotfiles
brew bundle --file=- <<EOF
$(cat nix/darwin/Brewfile)
EOF
```

### Reset Homebrew

If Homebrew is completely broken:

```bash
# Uninstall Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

# Reinstall Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Rebuild dotfiles to reinstall packages
cd ~/dotfiles
~/dotfiles/scripts/bin/rebuild
```

---

## Full System Recovery

If your entire dotfiles setup is broken, follow this recovery process.

### Step 1: Restore Git Repository

```bash
cd ~
git clone <your-dotfiles-repo-url> dotfiles.backup
mv dotfiles dotfiles.broken
mv dotfiles.backup dotfiles
cd dotfiles
```

### Step 2: Reset to Known Good State

```bash
# Find last known good commit
git log --oneline

# Checkout that commit
git checkout <good-commit-hash>

# Ensure flake.lock is updated
nix flake update
```

### Step 3: Rebuild System

```bash
# Rebuild from known good state
~/dotfiles/scripts/bin/rebuild
```

### Step 4: Test Configuration

```bash
# Test shell configuration
zsh -c 'echo "Shell OK"'

# Test git configuration
git config --list

# Test editor
nvim --version

# Test Homebrew
brew --version
```

---

## Emergency Procedures

### Build Fails During Rebuild

If `~/dotfiles/scripts/bin/rebuild` fails:

1. **Check error message** - Look for syntax errors or missing packages
2. **Roll back generation** - Use previous Nix generation
3. **Git revert** - Revert last commit if it caused the issue
4. **Check flake.lock** - Delete and regenerate: `rm flake.lock && nix flake update`

```bash
# Emergency rollback
sudo nix-env --switch-generation <previous-generation> --profile /nix/var/nix/profiles/system
sudo darwin-rebuild switch --rollback
```

### System Won't Boot

If Nix changes prevent macOS from booting:

1. **Boot into Recovery Mode** - Hold Command+R during startup
2. **Disable Nix launchd services** - Remove files from `/Library/LaunchDaemons/`
3. **Boot into Safe Mode** - Hold Shift during startup
4. **Remove Nix configuration** - Delete `/etc/nix/nix.conf`
5. **Reinstall macOS** - As last resort

### Corrupted Nix Store

If the Nix store is corrupted:

```bash
# Stop nix-daemon
sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist

# Backup current store (if possible)
sudo mv /nix /nix.backup

# Reinstall Nix
curl -L https://nixos.org/nix/install | sh

# Rebuild dotfiles
cd ~/dotfiles
~/dotfiles/scripts/bin/rebuild
```

### Git Repository Corruption

If the Git repository is corrupted:

```bash
cd ~/dotfiles

# Try to repair
git fsck --full

# If repair fails, clone fresh
cd ~
mv dotfiles dotfiles.corrupted
git clone <your-remote-url> dotfiles
cd dotfiles

# Rebuild
~/dotfiles/scripts/bin/rebuild
```

---

## Best Practices

### Regular Backups

1. **Commit frequently** - Commit changes after each major modification
2. **Tag releases** - Tag stable configurations:
   ```bash
   git tag -a v1.0.0 -m "Stable configuration"
   git push origin v1.0.0
   ```
3. **Push to remote** - Keep a remote backup on GitHub/GitLab
4. **Export configurations** - Periodically export configurations to external storage

### Before Major Changes

```bash
# Create a backup branch
git checkout -b backup-before-change

# Commit current state
git add .
git commit -m "Backup before major changes"

# Make your changes
# ...

# If needed, revert to backup
git checkout main
git merge backup-before-change
```

### Testing Changes

```bash
# Test in a temporary directory
cd /tmp
git clone ~/dotfiles test-dotfiles
cd test-dotfiles

# Make test changes
# ...

# If tests pass, apply to main
cd ~/dotfiles
git merge test-branch
```

---

## Additional Resources

- [NixOS Manual - Rollbacks](https://nixos.org/manual/nix/stable/package-management/rollbacks.html)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix-Darwin Documentation](https://daiderd.com/nix-darwin/)
- [Git Documentation](https://git-scm.com/doc)

---

## Contact & Support

If you encounter issues not covered in this guide:

1. Check the [NixOS Discourse](https://discourse.nixos.org/)
2. Search [GitHub Issues](https://github.com/nix-community/home-manager/issues)
3. Check [Nix-Darwin Issues](https://github.com/LnL7/nix-darwin/issues)