# Testing Guide

This guide explains how to test the install script and dotfiles changes without needing a new Mac.

## Table of Contents

- [Testing the Install Script](#testing-the-install-script)
- [Testing in a Virtual Machine](#testing-in-a-virtual-machine)
- [Testing on a Clean macOS Install](#testing-on-a-clean-macos-install)
- [Testing Specific Components](#testing-specific-components)
- [Automated Testing with CI/CD](#automated-testing-with-cicd)

---

## Testing the Install Script

### Method 1: Dry Run Mode (Safest)

The update script has a `--dry-run` mode that shows what would happen without making changes:

```bash
# Test the update process
~/dotfiles/scripts/bin/update --dry-run
```

This will:
- Show which flake inputs would be updated
- Display what packages would change
- Show the rebuild steps
- **Make no actual changes**

### Method 2: Test in a Temporary Directory

Create an isolated test environment:

```bash
# Create a test directory
mkdir -p /tmp/dotfiles-test
cd /tmp/dotfiles-test

# Clone your dotfiles
git clone ~/dotfiles test-repo
cd test-repo

# Modify the install script to use this test directory
# Edit install.sh and change DOTFILES_DIR to /tmp/dotfiles-test/test-repo

# Test the install
bash install.sh --dry-run
```

### Method 3: Review Mode

Before running any script, review what it will do:

```bash
# Review the install script
cat ~/dotfiles/install.sh | less

# Review the update script
cat ~/dotfiles/scripts/bin/update | less

# Check what would be installed
cat ~/dotfiles/nix/darwin/configuration.nix | grep -A5 "brews\|casks"
```

---

## Testing in a Virtual Machine

### Option 1: macOS Virtual Machine (Advanced)

**Requirements:**
- macOS host (Apple Silicon or Intel)
- UTM (free) or VMware Fusion/Parallels
- macOS IPSW file or installer

**Steps:**
1. Download UTM: https://mac.getutm.app/
2. Create a new macOS VM
3. Install macOS (use a clean install)
4. Run the install script in the VM
5. Test all functionality

**Pros:**
- Exact replica of real Mac
- Can snapshot and rollback
- Test destructive changes safely

**Cons:**
- Requires significant disk space (50GB+)
- Slow on Apple Silicon
- Time consuming to set up

---

### Option 2: Docker-based Testing (Limited)

While you can't run macOS in Docker, you can test Nix expressions:

```bash
# Test Nix syntax
cd ~/dotfiles
nix flake check

# Test build without applying
nix build .#homeConfigurations.user.activationPackage --dry-run

# Test in a Nix container (Linux only, not macOS features)
docker run -it -v ~/dotfiles:/dotfiles nixos/nix:latest
# Then inside container:
cd /dotfiles
nix flake check
```

**Note:** This tests Nix syntax but NOT macOS-specific features (Homebrew, macOS defaults, etc.)

---

## Testing on a Clean macOS Install

### Option 1: External Drive/Partition

**Create a test macOS installation:**

1. **Get an external SSD** (256GB+ recommended)
2. **Install macOS on the external drive:**
   - Restart Mac holding Option key
   - Choose "Install macOS"
   - Select external drive as target
3. **Boot from external drive:**
   - Restart holding Option key
   - Choose external drive
4. **Run install script:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh | bash
   ```
5. **Test everything:**
   - Open applications
   - Test terminal
   - Verify settings

**Pros:**
- Tests on real hardware
- Full macOS environment
- Can test recovery scenarios

**Cons:**
- Requires external drive
- Takes time to install macOS

---

### Option 2: Create a New User Account

**Test on the same Mac with a clean environment:**

```bash
# Create a new test user
sudo sysadminctl -addUser testuser -fullName "Test User" -password "testpass123"

# Switch to test user
su - testuser

# Install dotfiles
curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh | bash

# Test everything
# When done, switch back to your main user and delete test user
sudo sysadminctl -deleteUser testuser
```

**Pros:**
- No additional hardware needed
- Quick to set up
- Tests multi-user scenarios

**Cons:**
- Shares system-level Nix installation
- Some settings are system-wide (affects main user)
- Not a completely clean test

---

## Testing Specific Components

### Test Nix Flake Changes

```bash
cd ~/dotfiles

# Check syntax
nix flake check

# View what would change
nix flake metadata

# Test build (without applying)
nix build .#darwinConfigurations.m4pro.system --dry-run

# Build and inspect (don't activate)
nix build .#darwinConfigurations.m4pro.system
ls -la result/
```

### Test Home Manager Changes

```bash
cd ~/dotfiles

# Check home-manager config
home-manager build --flake .#user

# View generation diff
home-manager generations
home-manager diff-generations 1 2
```

### Test Shell Changes

```bash
# Test zsh syntax
zsh -n ~/dotfiles/config/zsh/custom.zsh

# Source in subshell (isolated)
(zsh -c "source ~/dotfiles/config/zsh/custom.zsh; echo 'Success'")

# Test individual modules
zsh -n ~/dotfiles/config/zsh/modules/*.zsh
```

### Test Homebrew Changes

```bash
# Validate Brewfile syntax
cd ~/dotfiles
brew bundle --file=- <<EOF
$(grep -A1000 "brews = \[" nix/darwin/configuration.nix | head -20)
EOF

# Check for outdated packages
brew outdated

# Simulate bundle install
brew bundle --dry-run
```

---

## Automated Testing with CI/CD

### GitHub Actions (Limited macOS Testing)

Create `.github/workflows/test.yml`:

```yaml
name: Test Dotfiles

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-nix-syntax:
    runs-on: ubuntu-latest  # Can't use macOS for free
    steps:
    - uses: actions/checkout@v3
    
    - name: Install Nix
      uses: cachix/install-nix-action@v20
      
    - name: Check Nix syntax
      run: nix flake check
      
    - name: Validate shell scripts
      run: |
        shellcheck scripts/bin/rebuild
        shellcheck scripts/bin/update
        shellcheck install.sh
        
    - name: Test zsh syntax
      run: |
        for file in config/zsh/modules/*.zsh; do
          zsh -n "$file"
        done
```

**Note:** GitHub Actions free tier doesn't include macOS runners. You'd need:
- Self-hosted macOS runner (your own Mac)
- Paid GitHub plan with macOS minutes
- Alternative CI with macOS support (Travis CI, CircleCI)

---

## Pre-Release Testing Checklist

Before publishing changes for others to use:

### Syntax Validation
- [ ] `nix flake check` passes
- [ ] All shell scripts pass `shellcheck`
- [ ] All zsh files pass `zsh -n`
- [ ] No trailing whitespace or syntax errors

### Local Testing
- [ ] `./scripts/bin/rebuild` completes successfully
- [ ] `./scripts/bin/update --dry-run` shows expected changes
- [ ] New terminal sessions load correctly
- [ ] All aliases work
- [ ] Key applications launch

### Documentation
- [ ] README.md is up to date
- [ ] BACKUPS.md includes new procedures
- [ ] TESTING.md is current
- [ ] Comments in code are clear

### Version Control
- [ ] All changes committed
- [ ] Commit messages are descriptive
- [ ] flake.lock is updated if needed
- [ ] No sensitive data in commits

---

## Testing the One-Command Installer

### Before Publishing the Install Script

1. **Test locally with dry-run:**
   ```bash
   bash ~/dotfiles/install.sh --dry-run
   ```

2. **Test in a fresh macOS VM** (if available)

3. **Test with a new user account:**
   ```bash
   sudo sysadminctl -addUser tester -fullName "Test" -password "test123"
   su - tester
   bash <(curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh)
   ```

4. **Review the script line by line:**
   ```bash
   cat ~/dotfiles/install.sh | less
   ```

5. **Check all URLs are correct:**
   - GitHub repo URL
   - Nix installer URL
   - Any download links

---

## Quick Test for Non-Tech Users

If a non-tech user wants to test without committing:

```bash
# Download and review first
curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh -o /tmp/test-install.sh

# Review it
cat /tmp/test-install.sh

# Run with dry-run mode (if supported)
bash /tmp/test-install.sh --dry-run

# Or review each step and confirm
# The script has prompts at key steps
```

---

## Troubleshooting Test Failures

### If Nix Flake Check Fails

```bash
# Get detailed error
nix flake check --show-trace

# Check specific file syntax
nix-instantiate --parse nix/home/home.nix
nix-instantiate --parse nix/darwin/configuration.nix
```

### If Build Fails in Test

```bash
# Check recent changes
cd ~/dotfiles
git log --oneline -10

# Try previous working version
git checkout HEAD~1
./scripts/bin/rebuild

# Bisect to find problematic commit
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>
```

### If VM Testing is Slow

```bash
# Use lighter alternatives
# Instead of full macOS VM:
# - Test Nix expressions with docker
# - Test shell scripts with shellcheck
# - Test on new user account (faster)
```

---

## Summary

**Best Testing Approaches:**

| Method | Effort | Accuracy | Use For |
|--------|--------|----------|---------|
| `--dry-run` | Low | Medium | Quick validation |
| Syntax checks | Low | Low | Catch basic errors |
| New user account | Medium | High | Realistic test |
| External drive | High | Very High | Full verification |
| macOS VM | Very High | Very High | Complete isolation |

**Recommendation:**
1. **Always** use `--dry-run` first
2. **Always** run syntax checks
3. **Before major changes** test on new user account
4. **Before releases** test on external drive or VM

---

## Next Steps

1. Add the GitHub Actions workflow for automated syntax checking
2. Set up a test user account for regular testing
3. Consider creating a macOS VM for major release testing
4. Document specific test cases for each component

See also: [BACKUPS.md](./BACKUPS.md) for rollback procedures if testing goes wrong.