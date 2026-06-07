# Devin CLI Global Configuration Setup

This document describes how to recreate the global Devin CLI configuration (rules, skills, MCP servers, and workflows) on a new machine.

## Overview

The dotfiles repository now contains **ALL** Devin CLI configuration as the **source of truth**:

| Component | Dotfiles Location | Symlinked To | Purpose |
|-----------|------------------|--------------|---------|
| **Global Rules** | `config/windsurf/global_rules.md` | `~/.codeium/windsurf/memories/` | Workspace lifecycle & compliance |
| **Global Skills** | `config/devin/skills/*.skill.md` | `~/.config/devin/skills/` | Cross-workspace verification |
| **MCP Config** | `config/devin/mcp/mcp_config.json` | `~/.codeium/windsurf/` | Model Context Protocol servers |
| **Base Config** | `config/devin/base/config.json` | Reference/backup | Devin CLI version info |
| **Workflows** | `config/devin/workflows/` | Future use | Custom workflows & recipes |

**Key principle:** All configuration is edited through the IDE but **written to dotfiles** via symlinks. This means:
- ✅ Changes auto-tracked in git
- ✅ No manual sync needed
- ✅ Complete reproducibility on new machines
- ✅ Version history of all AI assistant configuration

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  IDE reads/writes here                    ACTUAL SOURCE (git-tracked)│
│  ~/.codeium/windsurf/                    ~/dotfiles/config/         │
│                                                                     │
│  global_rules.md ────────────────────→ windsurf/global_rules.md    │
│  mcp_config.json ────────────────────→ devin/mcp/mcp_config.json     │
│                                                                     │
│  ~/.config/devin/                                                   │
│  skills/dotfiles-audit/SKILL.md ─────→ devin/skills/*.skill.md     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                        git commit & push
                              │
                              ▼
                    All machines in sync
```

---

## 1. Global Rules

### Purpose
The Global Workspace Architect, Lifecycle & Enterprise Compliance Engine. These rules govern how the agent operates across all your projects.

### Location
- **Source of truth:** `~/dotfiles/config/windsurf/global_rules.md`
- **Symlink:** `~/.codeium/windsurf/memories/global_rules.md`

### The 5 Phases

1. **Lifecycle Discovery** — Detect project type (Learning, WIP, Production, Monorepo)
2. **Core Loop Prevention** — Blueprint First, User Verification, Strict Rollback
3. **Autonomous Skill Generation** — Defensive execution, anti-decay, dependency verification
4. **Lifecycle Execution** — Mode-specific behavior paths
5. **Cross-Boundary Bucketing** — Route fixes to dotfiles (Bucket 1) or local .envrc (Bucket 2)

---

## 2. Global Skills

### Purpose
Reusable verification and automation routines available in every workspace.

### Location
- **Source of truth:** `~/dotfiles/config/devin/skills/*.skill.md`
- **Symlink:** `~/.config/devin/skills/<name>/SKILL.md`

### Available Skills

#### `dotfiles-audit`
**Triggers:** `user`, `model`, `always_on`  
**Purpose:** Verify dotfiles environment health from any workspace

**Usage:**
```
/dotfiles-audit  # From any workspace
```

**Checks:**
- Dotfiles repository presence (`~/dotfiles`)
- Core commands availability (`dot`, `pnpm`, `direnv`)
- Bucket 1: `dot rebuild` pattern
- Bucket 2: `dotenv-init` function
- Zsh module health
- Nix/Darwin system health
- Skills and rules sync

**Adding new skills:**
1. Create `~/dotfiles/config/devin/skills/<name>.skill.md`
2. Add symlink: `ln -sf ~/dotfiles/config/devin/skills/<name>.skill.md ~/.config/devin/skills/<name>/SKILL.md`
3. Commit to dotfiles

---

## 3. MCP (Model Context Protocol) Configuration

### Purpose
Connect Devin CLI to external tools and services via MCP servers.

### Location
- **Source of truth:** `~/dotfiles/config/devin/mcp/mcp_config.json`
- **Symlink:** `~/.codeium/windsurf/mcp_config.json`

### Current MCP Servers

```json
{
  "mcpServers": {
    "epicshop": {
      "command": "npx",
      "args": ["-y", "@epic-web/workshop-mcp"]
    }
  }
}
```

**Adding new MCP servers:**
1. Edit `~/dotfiles/config/devin/mcp/mcp_config.json`
2. Changes apply immediately (no IDE restart needed)
3. Commit to dotfiles

---

## 4. Local Dotfiles Configuration

Already in `~/dotfiles/.devin/` and tracked in git:

### Rules
- `plan-and-execute-guardrail.md` — Local implementation of global patterns

### Skills
- `verify-and-audit` — Run after code changes in dotfiles
- `integration-audit` — Verify global→local alignment

---

## 5. New Machine Setup

### Quick Setup (One Script)

Save this as `setup-devin-global.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "🔗 Setting up Devin CLI global configuration..."

# 1. Global Rules (symlinked from dotfiles)
mkdir -p ~/.codeium/windsurf/memories
if [[ -f ~/.codeium/windsurf/memories/global_rules.md && ! -L ~/.codeium/windsurf/memories/global_rules.md ]]; then
  echo "📦 Backing up original global_rules.md"
  mv ~/.codeium/windsurf/memories/global_rules.md \
     ~/.codeium/windsurf/memories/global_rules.md.bak.$(date +%Y%m%d)
fi
ln -sf ~/dotfiles/config/windsurf/global_rules.md \
       ~/.codeium/windsurf/memories/global_rules.md
echo "✅ Global rules: ~/.codeium/windsurf/memories/global_rules.md"

# 2. MCP Config (symlinked from dotfiles)
if [[ -f ~/.codeium/windsurf/mcp_config.json && ! -L ~/.codeium/windsurf/mcp_config.json ]]; then
  echo "📦 Backing up original mcp_config.json"
  mv ~/.codeium/windsurf/mcp_config.json \
     ~/.codeium/windsurf/mcp_config.json.bak.$(date +%Y%m%d)
fi
ln -sf ~/dotfiles/config/devin/mcp/mcp_config.json \
       ~/.codeium/windsurf/mcp_config.json
echo "✅ MCP config: ~/.codeium/windsurf/mcp_config.json"

# 3. Global Skills (symlinked from dotfiles)
mkdir -p ~/.config/devin/skills
cd ~/dotfiles/config/devin/skills
for skill_file in *.skill.md; do
  skill_name="${skill_file%.skill.md}"
  mkdir -p ~/.config/devin/skills/"$skill_name"
  ln -sf ~/dotfiles/config/devin/skills/"$skill_file" \
         ~/.config/devin/skills/"$skill_name"/SKILL.md
  echo "✅ Skill: $skill_name"
done

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Verification:"
echo "  ls -la ~/.codeium/windsurf/memories/global_rules.md"
echo "  ls -la ~/.codeium/windsurf/mcp_config.json"
echo "  ls -la ~/.config/devin/skills/*/SKILL.md"
echo ""
echo "Next: Restart Windsurf to load global rules"
```

Run it:
```bash
bash ~/dotfiles/setup-devin-global.sh
```

### Manual Setup (Step by Step)

```bash
# 1. Global Rules
mkdir -p ~/.codeium/windsurf/memories
ln -sf ~/dotfiles/config/windsurf/global_rules.md \
       ~/.codeium/windsurf/memories/global_rules.md

# 2. MCP Config
ln -sf ~/dotfiles/config/devin/mcp/mcp_config.json \
       ~/.codeium/windsurf/mcp_config.json

# 3. Global Skills
mkdir -p ~/.config/devin/skills/dotfiles-audit
ln -sf ~/dotfiles/config/devin/skills/dotfiles-audit.skill.md \
       ~/.config/devin/skills/dotfiles-audit/SKILL.md

# Verify
ls -la ~/.codeium/windsurf/memories/global_rules.md
ls -la ~/.codeium/windsurf/mcp_config.json
ls -la ~/.config/devin/skills/dotfiles-audit/SKILL.md
```

---

## 6. Workflow: Editing Configuration

### Day-to-Day Usage

| Action | What Happens |
|--------|-------------|
| **Edit global rules via IDE** | Change writes through symlink to `~/dotfiles/config/windsurf/global_rules.md` |
| **Edit MCP servers via IDE** | Change writes to `~/dotfiles/config/devin/mcp/mcp_config.json` |
| **Edit skills via IDE** | Change writes to `~/dotfiles/config/devin/skills/*.skill.md` |
| **Check git status** | Shows modified files in `config/windsurf/` or `config/devin/` |
| **Commit & push** | `cd ~/dotfiles && git commit -m "feat(global): ..." && git push` |
| **Pull on other machine** | Gets all latest configuration automatically |

### Example Commit Flow

```bash
# You just edited global rules via the IDE
cd ~/dotfiles
git diff config/windsurf/global_rules.md  # Review changes
git add config/windsurf/global_rules.md
git commit -m "feat(global-rules): add monorepo detection pattern

- Add .devin/mode marker file support
- Clarify workspace lifecycle transitions
- Add Epic Web playground auto-detection"
git push
```

---

## 7. Adding New Components

### Adding a New Global Skill

```bash
# 1. Create skill in dotfiles (source of truth)
cat > ~/dotfiles/config/devin/skills/my-new-skill.skill.md << 'EOF'
---
name: my-new-skill
description: What this skill does
triggers:
  - user
  - model
---

### Routine
1. Step one
2. Step two
EOF

# 2. Create symlink to IDE location
mkdir -p ~/.config/devin/skills/my-new-skill
ln -sf ~/dotfiles/config/devin/skills/my-new-skill.skill.md \
       ~/.config/devin/skills/my-new-skill/SKILL.md

# 3. Commit to dotfiles
cd ~/dotfiles
git add config/devin/skills/
git commit -m "feat(skills): add my-new-skill for X purpose"
git push
```

### Adding a New MCP Server

```bash
# 1. Edit the MCP config (through IDE or directly)
# Changes auto-write to dotfiles via symlink

# 2. Example: Add a new MCP server
# Edit ~/dotfiles/config/devin/mcp/mcp_config.json:
{
  "mcpServers": {
    "epicshop": {
      "command": "npx",
      "args": ["-y", "@epic-web/workshop-mcp"]
    },
    "new-server": {
      "command": "npx",
      "args": ["-y", "@org/new-mcp-server"]
    }
  }
}

# 3. Commit
cd ~/dotfiles
git add config/devin/mcp/
git commit -m "feat(mcp): add new-server for X integration"
git push
```

---

## 8. Validation

After setup, verify everything:

```bash
#!/bin/bash
echo "=== Devin CLI Configuration Validation ==="
echo ""

# Global Rules
echo "Global Rules:"
ls -la ~/.codeium/windsurf/memories/global_rules.md 2>/dev/null && \
  readlink ~/.codeium/windsurf/memories/global_rules.md | grep -q dotfiles && \
  echo "  ✅ Symlinked to dotfiles" || echo "  ❌ Not properly symlinked"

# MCP Config
echo "MCP Config:"
ls -la ~/.codeium/windsurf/mcp_config.json 2>/dev/null && \
  readlink ~/.codeium/windsurf/mcp_config.json | grep -q dotfiles && \
  echo "  ✅ Symlinked to dotfiles" || echo "  ❌ Not properly symlinked"

# Global Skills
echo "Global Skills:"
for skill_dir in ~/.config/devin/skills/*/; do
  skill_name=$(basename "$skill_dir")
  if [[ -L "$skill_dir/SKILL.md" ]]; then
    echo "  ✅ $skill_name (symlinked)"
  else
    echo "  ❌ $skill_name (not symlinked)"
  fi
done

# Local skills
echo "Local Skills:"
ls ~/dotfiles/.devin/skills/*/SKILL.md 2>/dev/null | wc -l | xargs -I {} echo "  {} local skills"

# Run audit
echo ""
echo "Running dotfiles-audit..."
/devin skills invoke dotfiles-audit 2>/dev/null || echo "  (Audit not available in this shell)"

echo ""
echo "=== Validation Complete ==="
```

---

## 9. Troubleshooting

### Symlink was replaced by regular file

If Windsurf ever replaces a symlink with a regular file:

```bash
# Fix global rules
mv ~/.codeium/windsurf/memories/global_rules.md \
   ~/.codeium/windsurf/memories/global_rules.md.bak.$(date +%Y%m%d)
ln -sf ~/dotfiles/config/windsurf/global_rules.md \
       ~/.codeium/windsurf/memories/global_rules.md

# Fix MCP config
mv ~/.codeium/windsurf/mcp_config.json \
   ~/.codeium/windsurf/mcp_config.json.bak.$(date +%Y%m%d)
ln -sf ~/dotfiles/config/devin/mcp/mcp_config.json \
       ~/.codeium/windsurf/mcp_config.json
```

### Rules not loading
1. Verify symlink: `readlink ~/.codeium/windsurf/memories/global_rules.md`
2. Check file exists in dotfiles: `ls ~/dotfiles/config/windsurf/global_rules.md`
3. Restart Windsurf completely

### Skills not found
- Verify symlink: `ls -la ~/.config/devin/skills/<name>/SKILL.md`
- Check frontmatter format (valid YAML)
- Ensure `name:` matches directory name

### MCP servers not connecting
- Verify symlink: `readlink ~/.codeium/windsurf/mcp_config.json`
- Check JSON syntax: `cat ~/.codeium/windsurf/mcp_config.json | python3 -m json.tool`
- Restart Windsurf

---

## 10. Summary

| Component | Dotfiles Source | Symlink Location | Git Tracked |
|-----------|----------------|------------------|-------------|
| Global Rules | `config/windsurf/global_rules.md` | `~/.codeium/windsurf/memories/` | ✅ Yes |
| MCP Config | `config/devin/mcp/mcp_config.json` | `~/.codeium/windsurf/` | ✅ Yes |
| Global Skills | `config/devin/skills/*.skill.md` | `~/.config/devin/skills/` | ✅ Yes |
| Base Config | `config/devin/base/config.json` | Reference only | ✅ Yes |
| Workflows | `config/devin/workflows/` | Future use | ✅ Yes |
| Local Rules | `.devin/rules/` | N/A (local) | ✅ Yes |
| Local Skills | `.devin/skills/` | N/A (local) | ✅ Yes |

**All Devin CLI configuration is now:**
- ✅ Stored in dotfiles (source of truth)
- ✅ Editable via IDE (through symlinks)
- ✅ Git-tracked automatically
- ✅ Reproducible on any new machine

---

## See Also

- `~/dotfiles/config/windsurf/global_rules.md` — Global rules (edit via IDE)
- `~/dotfiles/config/devin/mcp/mcp_config.json` — MCP servers
- `~/dotfiles/config/devin/skills/` — Global skills
- `~/dotfiles/.devin/rules/plan-and-execute-guardrail.md` — Local guardrails
- `~/dotfiles/README.md` — Main dotfiles documentation
