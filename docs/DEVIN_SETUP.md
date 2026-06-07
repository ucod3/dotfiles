# Devin CLI Global Configuration Setup

This document describes how to recreate the global Devin CLI configuration (rules and skills) on a new machine.

## Overview

The dotfiles repository now contains **both local AND global** Devin configuration:

| Type | Location | Source of Truth | Git Tracked |
|------|----------|-------------------|-------------|
| **Global Rules** | `~/.codeium/windsurf/memories/global_rules.md` → `~/dotfiles/config/windsurf/global_rules.md` | **Dotfiles** | ✅ Yes |
| **Global Skills** | `~/.config/devin/skills/` → `~/dotfiles/config/devin/skills/` | **Dotfiles** | ✅ Yes (via symlink) |
| **Local Rules** | `~/dotfiles/.devin/rules/` | Dotfiles | ✅ Yes |
| **Local Skills** | `~/dotfiles/.devin/skills/` | Dotfiles | ✅ Yes |

**Key advantage:** When you edit global rules via the IDE, changes are automatically written to the dotfiles repository (via symlink). No manual sync needed!

---

## 1. Global Rules Setup

### How It Works

```
┌─────────────────────────────────────────────────────────┐
│  IDE reads/writes here                                  │
│  ~/.codeium/windsurf/memories/global_rules.md           │
│         ↑                                               │
│    (symlink)                                            │
│         ↓                                               │
│  Source of truth (git-tracked)                          │
│  ~/dotfiles/config/windsurf/global_rules.md            │
└─────────────────────────────────────────────────────────┘
```

### Setup Steps (New Machine)

1. **Create symlink from IDE location to dotfiles:**
   ```bash
   mkdir -p ~/.codeium/windsurf/memories
   ln -sf ~/dotfiles/config/windsurf/global_rules.md ~/.codeium/windsurf/memories/global_rules.md
   ```

2. **Verify the symlink:**
   ```bash
   ls -la ~/.codeium/windsurf/memories/global_rules.md
   # Should show: -> /Users/you/dotfiles/config/windsurf/global_rules.md
   ```

3. **Restart Windsurf** to load the rules.

### Editing Global Rules

Simply edit via the IDE as normal. Because of the symlink:
- Changes are written to `~/dotfiles/config/windsurf/global_rules.md`
- Git tracks the changes automatically
- Commit and push to sync across machines

```bash
# After editing via IDE
cd ~/dotfiles
git status  # Will show global_rules.md as modified
git commit -m "feat(global-rules): describe your changes"
git push
```

### What's in the Global Rules

The global rules define 5 phases:

1. **Lifecycle Discovery** — Detect project type (Learning, WIP, Production, Monorepo)
2. **Core Loop Prevention** — Blueprint First, User Verification, Strict Rollback
3. **Cross-Boundary Bucketing** — Route fixes to dotfiles (Bucket 1) or local .envrc (Bucket 2)
4. **Skill Generation & Hygiene** — Defensive execution, anti-decay, dependency verification
5. **Lifecycle Execution** — Mode-specific behavior paths

---

## 2. Global Skills Setup

### How It Works

Same symlink pattern as global rules:

```
~/.config/devin/skills/dotfiles-audit/SKILL.md
         ↑
    (symlink)
         ↓
~/dotfiles/config/devin/skills/dotfiles-audit.skill.md
```

### Setup Steps (New Machine)

```bash
# Create directory and symlink
mkdir -p ~/.config/devin/skills/dotfiles-audit
ln -sf ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md \
       ~/.config/devin/skills/dotfiles-audit/SKILL.md

# Verify
ls -la ~/.config/devin/skills/dotfiles-audit/SKILL.md
```

### Available Global Skills

#### `dotfiles-audit`
**Purpose:** Verify dotfiles environment health from any workspace

**Usage:**
```
/dotfiles-audit  # From any workspace
```

**What it checks:**
- Dotfiles repository presence (`~/dotfiles`)
- Core commands availability (`dot`, `pnpm`, `direnv`)
- Bucket 1: `dot rebuild` pattern
- Bucket 2: `dotenv-init` function
- Zsh module health
- Nix/Darwin system health
- Skills and rules sync

---

## 3. Local Dotfiles Skills (Already Set Up)

These are in `~/dotfiles/.devin/skills/` and tracked in git:

### `verify-and-audit`
- **Triggers:** user + model
- **Purpose:** Run after code changes in dotfiles
- **Checks:** Static analysis, zsh sourcing, pre-commit hook

### `integration-audit`
- **Triggers:** user + model
- **Purpose:** Verify global_rules.md → dotfiles alignment
- **Checks:** Cross-boundary bucketing, hostname resolution, lifecycle modes

---

## 4. Complete Setup Script (One Command)

For quick setup on a new machine:

```bash
#!/bin/bash
# save as: setup-devin-global.sh

set -euo pipefail

echo "🔗 Setting up Devin CLI global configuration..."

# Global Rules (symlinked from dotfiles)
mkdir -p ~/.codeium/windsurf/memories
if [[ -f ~/.codeium/windsurf/memories/global_rules.md && ! -L ~/.codeium/windsurf/memories/global_rules.md ]]; then
  echo "📦 Backing up original global_rules.md"
  mv ~/.codeium/windsurf/memories/global_rules.md ~/.codeium/windsurf/memories/global_rules.md.bak.$(date +%Y%m%d)
fi
ln -sf ~/dotfiles/config/windsurf/global_rules.md ~/.codeium/windsurf/memories/global_rules.md
echo "✅ Global rules symlinked"

# Global Skill (symlinked from dotfiles)
mkdir -p ~/.config/devin/skills/dotfiles-audit
ln -sf ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md \
       ~/.config/devin/skills/dotfiles-audit/SKILL.md
echo "✅ Global skill symlinked"

echo ""
echo "🎉 Setup complete! Restart Windsurf to load global rules."
echo ""
echo "Verification:"
echo "  ls -la ~/.codeium/windsurf/memories/global_rules.md"
echo "  ls -la ~/.config/devin/skills/dotfiles-audit/SKILL.md"
```

---

## 5. Validation

After setup, verify everything works:

```bash
# Check global rules symlink
ls -la ~/.codeium/windsurf/memories/global_rules.md
# Should show: -> /Users/you/dotfiles/config/windsurf/global_rules.md

# Check global skill symlink
ls -la ~/.config/devin/skills/dotfiles-audit/SKILL.md
# Should show: -> /Users/you/dotfiles/config/devin/skills/dotfiles-audit.skill.md

# Check local skills exist
ls ~/dotfiles/.devin/skills/*/SKILL.md

# Run the dotfiles audit
/dotfiles-audit
```

---

## 6. Workflow: Editing Global Rules

### Day-to-Day Usage

1. **Edit via IDE** — Just use Windsurf's AI rules editor as normal
2. **Changes auto-save to dotfiles** — Because of the symlink
3. **Commit when ready:**
   ```bash
   cd ~/dotfiles
   git diff config/windsurf/global_rules.md  # Review changes
   git add config/windsurf/global_rules.md
   git commit -m "feat(global-rules): your description"
   git push
   ```

### Syncing to Another Machine

```bash
# On new machine, after installing dotfiles
git pull  # Gets latest global_rules.md
# Symlinks are already set up from install script
```

---

## Troubleshooting

### Rules not loading
- Ensure symlink exists: `ls -la ~/.codeium/windsurf/memories/global_rules.md`
- Verify it points to dotfiles: `readlink ~/.codeium/windsurf/memories/global_rules.md`
- Restart Windsurf completely

### Symlink was replaced by regular file
If Windsurf ever replaces the symlink with a regular file:
```bash
# Re-create the symlink
mv ~/.codeium/windsurf/memories/global_rules.md \
   ~/.codeium/windsurf/memories/global_rules.md.bak
ln -sf ~/dotfiles/config/windsurf/global_rules.md \
       ~/.codeium/windsurf/memories/global_rules.md
```

### Skills not found
- Verify symlink: `ls -la ~/.config/devin/skills/dotfiles-audit/SKILL.md`
- Check file exists in dotfiles: `ls ~/dotfiles/config/devin/skills/`
- Ensure frontmatter is valid YAML

### Cross-boundary bucketing not working
- Verify `dot` command in PATH: `which dot`
- Check `dot rebuild` works: `cd ~/dotfiles && dot validate`
- Ensure `dotenv-init` available: `type dotenv-init`

---

## Summary

| Component | Location | Type | Git Tracked |
|-----------|----------|------|-------------|
| Global Rules | `~/.codeium/windsurf/memories/global_rules.md` → `~/dotfiles/config/windsurf/global_rules.md` | **Symlink** | ✅ Yes |
| Global Skill | `~/.config/devin/skills/dotfiles-audit/SKILL.md` → `~/dotfiles/config/devin/skills/dotfiles-audit.skill.md` | **Symlink** | ✅ Yes |
| Local Rules | `~/dotfiles/.devin/rules/` | Regular files | ✅ Yes |
| Local Skills | `~/dotfiles/.devin/skills/` | Regular files | ✅ Yes |

**Key benefit:** Edit via IDE → Changes auto-tracked in dotfiles → Commit and push → Sync everywhere

---

## See Also

- `~/dotfiles/config/windsurf/global_rules.md` — Global rules (source of truth)
- `~/dotfiles/.devin/rules/plan-and-execute-guardrail.md` — Local implementation
- `~/dotfiles/README.md` — Main dotfiles documentation
- `~/dotfiles/TESTING.md` — Testing and validation procedures
