# Initial Setup Guide

This guide explains what to do after running the install script to get your development environment fully configured.

## Quick Start Checklist

After running `install.sh`, complete these steps:

- [ ] Restart your terminal
- [ ] Set up Node.js (via pnpm)
- [ ] Verify core tools work
- [ ] Configure Git (if not done)
- [ ] Test your workflow

---

## 1. Restart Your Terminal

**Why:** The installer sets up new shell configuration that requires a fresh terminal session.

```bash
# Close and reopen your terminal
# Or run:
exec zsh
```

**What should happen:**
- Oh My Zsh loads with the robbyrussell theme
- You see command suggestions as you type
- Syntax highlighting is active
- The `update` and `change` aliases work

---

## 2. Set Up Node.js (via pnpm)

**Important:** pnpm is pre-installed, but Node.js is NOT installed initially.

**Why:** We use pnpm to manage Node.js versions, saving disk space. Node.js is installed on-demand.

### Option A: Auto-Install (Recommended)

Simply run any pnpm command and it will auto-install Node.js LTS:

```bash
# This will automatically install Node.js LTS
pnpm --version

# Or start a new project
mkdir my-project && cd my-project
pnpm init
# Node.js will be auto-installed when needed
```

### Option B: Manual Install (If you want control)

```bash
# Install Node.js LTS globally via pnpm
pnpm env use --global node@lts

# Or install a specific version
pnpm env use --global node@20
pnpm env use --global node@18

# Check installed versions
pnpm env list

# Switch versions
pnpm env use --global node@20
```

### Option C: Per-Project Node.js (Most Flexible)

```bash
# In each project directory, run:
pnpm env use --global node@$(cat .nvmrc)

# Or use the helper function:
ensure-node 20
```

**What this gives you:**
- Node.js managed by pnpm (not system package manager)
- Easy version switching per project
- No need to reinstall node_modules for every project (pnpm's store is shared)

---

## 3. Verify Core Tools

Test that everything is working:

```bash
# Test pnpm + Node.js
pnpm --version
node --version

# Test Git
git --version
git config user.name    # Should show your name
git config user.email   # Should show your email

# Test terminal features
# Type 'gi' and see if you get suggestions
# Type an alias and see the reminder

# Test applications
code --version          # VS Code
nvim --version          # Neovim
brew --version          # Homebrew
```

---

## 4. Configure Git (If Not Done)

If Git wasn't configured during install:

```bash
# Set your identity
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Optional: Set default editor
git config --global core.editor "nvim"

# Verify
git config --list
```

---

## 5. Test Your Workflow

### Create a Test Project

```bash
# Create a directory
mkdir ~/test-project
cd ~/test-project

# Initialize with pnpm
pnpm init

# Install a package
pnpm add lodash

# Check disk space usage (should be minimal due to pnpm store)
du -sh node_modules
```

### Test Dotfiles Commands

```bash
# Test update command (dry run first)
update --dry-run

# Test change command
change
# This should open VS Code with your dotfiles

# Test aliases
ga --version            # git add (via alias)
gs                      # git status (via alias)
```

---

## Common First-Time Issues

### Issue: "node: command not found"

**Solution:** Node.js isn't installed yet. Run:
```bash
pnpm env use --global node@lts
```

### Issue: "pnpm: command not found"

**Solution:** Terminal not restarted. Run:
```bash
exec zsh
# or close and reopen terminal
```

### Issue: Git identity not set

**Solution:**
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Issue: VS Code command not found

**Solution:** VS Code may need to be launched first. Open VS Code manually, then:
```bash
# In VS Code, open Command Palette (Cmd+Shift+P)
# Type "Shell Command: Install 'code' command in PATH"
# Click it
```

### Issue: Zsh modules not found

**Solution:** The modules directory wasn't linked. Run:
```bash
# Rebuild to ensure all links are set up
~/dotfiles/scripts/bin/rebuild
```

---

## Next Steps

### 1. Set Up SSH Keys (for GitHub)

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub | pbcopy

# Add to GitHub: https://github.com/settings/keys
```

### 2. Configure Your Editor

#### VS Code Settings

Your VS Code settings are already configured in `~/dotfiles/config/vscode/settings.json`.

To verify they're active:
```bash
# Check if settings are linked
ls -la ~/Library/Application\ Support/Code\ -\ Insiders/User/settings.json

# Should show a symlink to your dotfiles
```

#### Neovim

Neovim is pre-configured with:
- Dracula theme
- LSP support (Lua, Python, TypeScript)
- Telescope for file finding
- Treesitter for syntax highlighting

Test it:
```bash
nvim
# Inside nvim, type :checkhealth
```

### 3. Set Up Project Templates (Optional)

If you use EpicWeb or similar workshops:

```bash
# Clone workshop materials
workshop init  # Uses the workshop.zsh functions
```

### 4. Customize Your Shell

Edit your shell configuration:

```bash
# Edit aliases
change
# Edit ~/dotfiles/config/zsh/modules/aliases.zsh

# Edit utility functions
nvim ~/dotfiles/config/zsh/modules/utils.zsh

# Add environment variables
nvim ~/dotfiles/config/zsh/modules/exports.zsh
```

After editing, apply changes:
```bash
source ~/.zshrc
# or just type:
update
```

---

## Maintenance Schedule

### Weekly
```bash
# Every Friday (or when you remember)
update
```

### Monthly
```bash
# Clean up old generations
nix-collect-garbage -d

# Update and push flake.lock
update --auto
cd ~/dotfiles && git push
```

### As Needed
```bash
# When you need a different Node.js version
pnpm env use --global node@XX

# When you add new software
# Edit nix/darwin/configuration.nix
~/dotfiles/scripts/bin/rebuild
```

---

## Understanding Your Setup

### Directory Structure

```
~/dotfiles/              # Your dotfiles repository
├── config/              # Application configs
│   ├── git/            # Git configuration
│   ├── nvim/           # Neovim configuration
│   ├── zsh/            # Zsh modules
│   └── ghostty/        # Terminal config
├── nix/                 # Nix configuration
│   ├── darwin/         # macOS system settings
│   └── home/           # User environment
├── scripts/bin/         # Utility scripts
│   ├── rebuild        # Main rebuild command
│   ├── update         # Update everything
│   └── check-*        # Various checks
└── flake.nix           # Main Nix configuration
```

### Key Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `update` | Update all packages | Weekly |
| `rebuild` | Apply configuration changes | After editing dotfiles |
| `change` | Edit dotfiles | When customizing |
| `workshop` | Workshop helpers | During EpicWeb courses |
| `pnpm` | Package manager | Daily development |
| `nvim` | Editor | When editing code |
| `ga`, `gcmsg`, `gp` | Git shortcuts | Daily Git work |

### How Updates Work

```
1. You run: update
2. Script updates:
   - nix flake inputs (nixpkgs, home-manager, etc.)
   - Homebrew packages
3. Script commits flake.lock to Git
4. Script rebuilds system
5. New packages and settings applied
```

### How pnpm Saves Space

Traditional approach (npm/yarn):
```
Project A: node_modules (500MB)
Project B: node_modules (500MB) - mostly same packages
Project C: node_modules (500MB) - mostly same packages
Total: 1.5GB
```

Your pnpm approach:
```
Central store: packages (500MB) - shared across all projects
Project A: node_modules (hard links) - negligible size
Project B: node_modules (hard links) - negligible size
Project C: node_modules (hard links) - negligible size
Total: ~500MB (plus small per-project overhead)
```

**Result:** 3x less disk space, faster installs, instant package sharing.

---

## Getting Help

### Documentation
- **BACKUPS.md** - Recovery and rollback procedures
- **TESTING.md** - Testing the install script
- **README.md** - Main documentation

### Commands
```bash
# Check system health
~/dotfiles/scripts/bin/check-brew-manual-installers

# View Nix generations
darwin-rebuild --list-generations

# Check what would change
update --dry-run
```

### Online Resources
- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [nix-darwin Documentation](https://github.com/LnL7/nix-darwin)
- [pnpm Documentation](https://pnpm.io/motivation)

---

## You're All Set! 🎉

Your Mac now has:
- ✅ Modern terminal (Ghostty)
- ✅ Smart shell (Zsh with Oh My Zsh)
- ✅ Efficient package manager (pnpm)
- ✅ Powerful editor (Neovim)
- ✅ All your applications
- ✅ Optimized macOS settings
- ✅ Fully reproducible setup

**Start developing:**
```bash
mkdir my-new-project
cd my-new-project
pnpm init
# Start coding!
```

Happy coding! 🚀