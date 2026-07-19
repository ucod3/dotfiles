# macOS Dotfiles

A modern, reproducible macOS development environment using Nix flakes, nix-darwin, Home Manager, and Homebrew.

## 🚀 Quick Start (One-Command Install)

### For Everyone (Tech and Non-Tech Users)

**Option 1: Copy and paste this into Terminal:**
```bash
curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh | bash
```

**Option 2: If you prefer to review first:**
```bash
# Download and review
curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh -o install.sh

# Review the script
cat install.sh

# Run it
bash install.sh
```

**What this does:**
1. ✅ Checks system requirements (macOS, Apple Silicon)
2. ✅ Installs Xcode Command Line Tools (if needed)
3. ✅ Installs Nix package manager (if needed)
4. ✅ Configures Git (if needed)
5. ✅ Installs Rosetta 2 for Intel compatibility (if needed)
6. ✅ Clones this dotfiles repository
7. ✅ Builds and configures your entire macOS system
8. ✅ Installs all applications and development tools

**Time required:** 15-30 minutes (mostly automatic)

**No technical knowledge required!** The installer handles everything.

---

## 📋 What's Included

### Terminal & Shell
- **Ghostty** - Modern, fast terminal emulator
- **Zsh** with Oh My Zsh
- **Autosuggestions** - Fish-like suggestions
- **Syntax highlighting** - Command validation
- **you-should-use** - Reminds you of aliases
- **fzf** - Fuzzy finder for files/commands
- **zoxide** - Smarter cd command

### Development Tools
- **Neovim** - Modern Vim with LSP support
  - Telescope (fuzzy finder)
  - Treesitter (syntax highlighting)
  - Lualine (status bar)
  - Dracula theme
  - LSP: lua-language-server, pyright, typescript-language-server
- **Git** - Modern workflow configuration
- **Node.js** - Via pnpm and version management
- **Python** - With pygments and development tools

### Applications (via Homebrew)
- **Browsers:** Arc, Microsoft Edge Canary, Zen Browser
- **Development:** VS Code, Zed, Ghostty, Codex, Devin Desktop
- **Productivity:** Amethyst (window manager), Insync, WPS Office
- **Utilities:** AnyDesk, Windscribe VPN, Adobe Acrobat Reader, Antigravity

### macOS System Configuration
- Dock auto-hide for more screen space
- Faster key repeat rate
- Show all file extensions
- Disable window animations
- Optimized Finder settings

---

## 🎯 Who Is This For?

### Developers
- **Perfect for:** Web developers, software engineers, DevOps
- **Benefits:** Consistent environment across machines, easy onboarding, version-controlled tools
- **Setup time:** 15 minutes vs 4-8 hours manual setup

### Non-Technical Users
- **Perfect for:** Students, professionals, anyone wanting a productive Mac
- **Benefits:** One command sets up everything, professional-grade tools, easy to maintain
- **No technical knowledge required**

### Teams
- **Perfect for:** Development teams, remote workers
- **Benefits:** Identical environments, easy to share, quick onboarding
- **New team member:** Productive in 15 minutes instead of days

---

## 📖 Manual Installation (Advanced Users)

If you prefer manual control or the automated installer doesn't work:

### Prerequisites
- macOS (optimized for Apple Silicon, works on Intel)
- Xcode Command Line Tools: `xcode-select --install`
- Git configured with your name and email

### Step 1: Install Nix
```bash
curl -L https://nixos.org/nix/install | sh
```

### Step 2: Clone Dotfiles
```bash
git clone https://github.com/ucod3/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### Step 3: Build System
```bash
./scripts/bin/rebuild
```

---

## 🛠️ Daily Usage

### Essential Commands

| Command | Description |
|---------|-------------|
| `update` | Update all packages and system configuration |
| `change` | Quick edit to your dotfiles |
| `nvim` | Launch Neovim editor |
| `code` | Launch VS Code |
| `ga` | Git add (alias) |
| `gcmsg` | Git commit with message (alias) |
| `workshop` | Workshop helper for EpicWeb courses |

### Managing Your Dotfiles

**Edit configuration:**
```bash
cd ~/dotfiles
# Edit files...
nix flake update  # Update dependencies
./scripts/bin/rebuild  # Apply changes
```

**View recent changes:**
```bash
cd ~/dotfiles
git log --oneline -10
```

**Rollback if something breaks:**
```bash
cd ~/dotfiles
git checkout HEAD -- .  # Revert to last commit
./scripts/bin/rebuild
```

---

## 🔧 Customization

### Adding New Applications

Edit `hosts/default.nix`:
```nix
# Add to environment.systemPackages for Nix packages
environment.systemPackages = with pkgs; [
  brave
  gh
  your-new-package  # Add here
];

# Or add to Homebrew casks
brews = [ "your-brew-package" ];
casks = [ "your-cask-app" ];
```

### Adding Shell Aliases

Edit `config/zsh/modules/aliases.zsh`:
```zsh
alias myalias='my command'
```

### Machine-Specific Configuration

Create `~/.zshrc.local` for settings that shouldn't be in Git:
```zsh
# Machine-specific exports
export PRIVATE_API_KEY="..."
```

---

## 🆘 Troubleshooting

### Build Fails

**Problem:** "Git tree is dirty" warning  
**Solution:**
```bash
cd ~/dotfiles
git add .
git commit -m "WIP: current state"
./scripts/bin/rebuild
```

**Problem:** Permission denied errors  
**Solution:**
```bash
# Fix Nix permissions
sudo chown -R $(whoami) /nix
```

**Problem:** Package not found  
**Solution:**
```bash
# Update flake inputs
nix flake update
./scripts/bin/rebuild
```

### Recovery Procedures

See [BACKUPS.md](./BACKUPS.md) for detailed recovery procedures including:
- Rolling back to previous generations
- Recovering from broken builds
- Full system recovery steps

---

## 🏗️ Architecture

### Technology Stack
- **Nix Flakes** - Reproducible package management
- **nix-darwin** - macOS system configuration
- **Home Manager** - User environment management
- **Homebrew** - macOS-native applications
- **Git** - Version control and backup

### Directory Structure
```
dotfiles/
├── config/              # Application configurations
│   ├── git/            # Git configuration
│   ├── nvim/           # Neovim configuration
│   ├── zsh/            # Zsh modules and configs
│   └── ghostty/        # Terminal configuration
├── hosts/              # macOS system config (shared, parameterized by user)
├── nix/                # Nix configuration
│   └── home/           # Home Manager config
├── scripts/            # Utility scripts
│   └── bin/            # Executable scripts
├── flake.nix           # Main Nix flake
├── install.sh          # One-command installer ⭐
└── BACKUPS.md          # Recovery documentation
```

### Modular Shell Configuration
The shell configuration is split into focused modules:
- `init.zsh` - Basic initialization
- `node.zsh` - Node.js and package management
- `utils.zsh` - Utility functions
- `npm-compat.zsh` - npm compatibility helpers
- `aliases.zsh` - Command shortcuts
- `workshop.zsh` - Workshop helpers
- `exports.zsh` - Environment variables

---

## � AI Assistant Configuration (Devin CLI)

This dotfiles repository includes comprehensive configuration for the [Devin CLI](https://cli.devin.ai/) AI assistant:

### What's Included

| Component | Location | Purpose |
|-----------|----------|---------|
| **Global Rules** | `config/windsurf/global_rules.md` | Workspace lifecycle & compliance engine  |
| **Global Skills** | `config/devin/skills/` | Cross-workspace verification tools  |
| **MCP Config** | `config/devin/mcp/` | Model Context Protocol server definitions |
| **Local Rules** | `.devin/rules/` | Dotfiles-specific guardrails |
| **Local Skills** | `.devin/skills/` | Dotfiles verification and audit routines |

All global configuration is **symlinked** from dotfiles — edit via IDE, changes auto-tracked in git.

### Key Features

- **Cross-Boundary Bucketing** — Automatically route fixes to dotfiles (global) or local `.envrc` (project)
- **Lifecycle Detection** — Auto-detect Epic Web workshops, npm projects, production environments
- **Proactive Verification** — Skills run automatically to ensure code quality
- **Edit via IDE → Auto-tracked** — All changes through symlinks commit to git automatically
- **Strict Compliance** — Git & Nix tree awareness, rollback procedures, purity checks

### Setup After Dotfiles Install

```bash
# One-command setup of all Devin global configuration
mkdir -p ~/.codeium/windsurf/memories ~/.config/devin/skills
cd ~/dotfiles/config/devin/skills && for f in *.skill.md; do mkdir -p ~/.config/devin/skills/${f%.skill.md}; ln -sf ~/dotfiles/config/devin/skills/$f ~/.config/devin/skills/${f%.skill.md}/SKILL.md; done
ln -sf ~/dotfiles/config/windsurf/global_rules.md ~/.codeium/windsurf/memories/global_rules.md
ln -sf ~/dotfiles/config/devin/mcp/mcp_config.json ~/.codeium/windsurf/mcp_config.json
```

Or use the setup script:
```bash
bash ~/dotfiles/docs/setup-devin-global.sh
```

**How it works:** When you edit global rules, skills, or MCP config via the IDE, changes write through symlinks to the dotfiles repo. Simply `git commit` and `git push` to sync across machines.

See [docs/DEVIN_SETUP.md](./docs/DEVIN_SETUP.md) for complete setup, workflow, and troubleshooting.

---

## �🤝 Contributing

This is a personal dotfiles repository, but feel free to:
- Fork it for your own use
- Submit issues for bugs
- Suggest improvements

---

## 📝 License

MIT License - Feel free to use, modify, and share.

---

## 🌟 Why This Approach?

### Traditional macOS Setup
```
1. Install apps one by one from websites
2. Configure settings manually
3. Repeat for every new Mac
4. Lose everything when Mac dies
5. Hope you remember all the apps
Time: 4-8 hours per machine
```

### This Dotfiles Approach
```
1. Run one command
2. Everything installs automatically
3. Same setup on every Mac
4. Full backup in Git
5. Exact reproduction possible
Time: 15 minutes per machine
```

**Benefits:**
- ✅ **Reproducible** - Same setup every time
- ✅ **Version controlled** - Track changes, rollback if needed
- ✅ **Self-documenting** - Code describes configuration
- ✅ **Shareable** - Team members get identical setups
- ✅ **Maintainable** - Update everything with one command
- ✅ **Recoverable** - Full system restore in minutes

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/ucod3/dotfiles/issues)
- **Documentation:** See [BACKUPS.md](./BACKUPS.md) for troubleshooting
- **Nix Manual:** [NixOS Documentation](https://nixos.org/manual/nix/stable/)

---

**Made with ❤️ for productive macOS development**