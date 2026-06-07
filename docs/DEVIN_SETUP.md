# Devin CLI Global Configuration Setup

This document describes how to recreate the global Devin CLI configuration (rules and skills) on a new machine.

## Overview

The dotfiles repository contains **local** Devin configuration (`.devin/rules/` and `.devin/skills/`) that is project-specific and committed to git.

However, **global** Devin configuration lives outside the dotfiles repo and must be set up separately:

| Type | Location | Purpose |
|------|----------|---------|
| **Global Rules** | `~/.codeium/windsurf/memories/global_rules.md` | Apply to all workspaces |
| **Global Skills** | `~/.config/devin/skills/` | Available in every project |
| **Local Rules** | `~/dotfiles/.devin/rules/` | Dotfiles-specific implementation |
| **Local Skills** | `~/dotfiles/.devin/skills/` | Dotfiles-specific verification |

---

## 1. Global Rules Setup

### Location
```
~/.codeium/windsurf/memories/global_rules.md
```

### Purpose
The Global Workspace Architect, Lifecycle & Enterprise Compliance Engine. These rules govern how the agent operates across all your projects.

### Setup Steps

1. **Copy from dotfiles backup:**
   ```bash
   mkdir -p ~/.codeium/windsurf/memories
   cp ~/dotfiles/config/windsurf/global_rules.md.backup ~/.codeium/windsurf/memories/global_rules.md
   ```

2. **Verify installation:**
   ```bash
   ls -la ~/.codeium/windsurf/memories/global_rules.md
   ```

3. **Restart Windsurf** to load the new rules.

### What's in the Global Rules

The global rules define 5 phases:

1. **Lifecycle Discovery** — Detect project type (Learning, WIP, Production, Monorepo)
2. **Core Loop Prevention** — Blueprint First, User Verification, Strict Rollback
3. **Cross-Boundary Bucketing** — Route fixes to dotfiles (Bucket 1) or local .envrc (Bucket 2)
4. **Skill Generation & Hygiene** — Defensive execution, anti-decay, dependency verification
5. **Lifecycle Execution** — Mode-specific behavior paths

---

## 2. Global Skills Setup

### Location
```
~/.config/devin/skills/
```

### Available Global Skills

#### `dotfiles-audit`
**Purpose:** Verify dotfiles environment health from any workspace

**Setup:**
```bash
mkdir -p ~/.config/devin/skills/dotfiles-audit
cp ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md ~/.config/devin/skills/dotfiles-audit/SKILL.md
```

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

These are already in `~/dotfiles/.devin/skills/` and tracked in git:

### `verify-and-audit`
- **Triggers:** user + model
- **Purpose:** Run after code changes in dotfiles
- **Checks:** Static analysis, zsh sourcing, pre-commit hook

### `integration-audit`
- **Triggers:** user + model
- **Purpose:** Verify global_rules.md → dotfiles alignment
- **Checks:** Cross-boundary bucketing, hostname resolution, lifecycle modes

---

## 4. Symlink Strategy (Alternative)

Instead of copying, you can symlink the global skill to keep it in version control:

```bash
# Make dotfiles the source of truth
mkdir -p ~/.config/devin/skills/dotfiles-audit
ln -sf ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md \
       ~/.config/devin/skills/dotfiles-audit/SKILL.md
```

This ensures changes to the skill are captured in dotfiles git history.

---

## 5. Validation

After setup, verify everything works:

```bash
# Check global rules exist
ls ~/.codeium/windsurf/memories/global_rules.md

# Check global skill exists
ls ~/.config/devin/skills/dotfiles-audit/SKILL.md

# Check local skills exist
ls ~/dotfiles/.devin/skills/*/SKILL.md

# Run the dotfiles audit
/devin skills invoke dotfiles-audit
```

---

## Troubleshooting

### Rules not loading
- Ensure file is at exact path: `~/.codeium/windsurf/memories/global_rules.md`
- Restart the IDE completely
- Check file permissions (should be readable)

### Skills not found
- Verify `SKILL.md` filename (case-sensitive)
- Check directory structure: `~/.config/devin/skills/<name>/SKILL.md`
- Ensure frontmatter has valid YAML format

### Cross-boundary bucketing not working
- Verify `dot` command is in PATH: `which dot`
- Check `dot rebuild` works: `cd ~/dotfiles && dot validate`
- Ensure `dotenv-init` is available: `type dotenv-init`

---

## Summary

| Component | Setup Command | Verification |
|-----------|---------------|--------------|
| Global Rules | `cp ~/dotfiles/config/windsurf/global_rules.md.backup ~/.codeium/windsurf/memories/global_rules.md` | `ls ~/.codeium/windsurf/memories/global_rules.md` |
| Global Skill | `mkdir -p ~/.config/devin/skills/dotfiles-audit && cp ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md ~/.config/devin/skills/dotfiles-audit/SKILL.md` | `ls ~/.config/devin/skills/dotfiles-audit/SKILL.md` |
| Local Skills | Already in `~/dotfiles/.devin/skills/` | `ls ~/dotfiles/.devin/skills/*/SKILL.md` |

---

## See Also

- `~/dotfiles/.devin/rules/plan-and-execute-guardrail.md` — Local implementation of global rules
- `~/dotfiles/README.md` — Main dotfiles documentation
- `~/dotfiles/TESTING.md` — Testing and validation procedures
