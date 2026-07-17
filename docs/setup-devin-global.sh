#!/bin/bash
# Devin CLI Global Configuration Setup Script
# Run this after installing dotfiles to set up global Devin configuration

set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"

echo "=========================================="
echo "Devin CLI Global Configuration Setup"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to backup existing file
backup_if_exists() {
  local file="$1"
  if [[ -f "$file" && ! -L "$file" ]]; then
    local backup_name="${file}.bak.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}📦 Backing up: $file → $(basename "$backup_name")${NC}"
    mv "$file" "$backup_name"
  fi
}

# Function to create symlink
create_symlink() {
  local source="$1"
  local target="$2"
  local description="$3"

  # Ensure target directory exists
  mkdir -p "$(dirname "$target")"

  # Backup if exists and not symlink
  backup_if_exists "$target"

  # Remove existing symlink if wrong
  if [[ -L "$target" ]]; then
    rm "$target"
  fi

  # Create symlink
  if ln -sf "$source" "$target"; then
    echo -e "${GREEN}✅ $description${NC}"
    echo "   $target → $source"
  else
    echo -e "${RED}❌ Failed to create symlink: $description${NC}"
    return 1
  fi
}

echo "Setting up symlinks from IDE locations to dotfiles..."
echo ""

# 1. Global Rules
create_symlink \
  "$DOTFILES_ROOT/config/windsurf/global_rules.md" \
  "$HOME/.codeium/windsurf/memories/global_rules.md" \
  "Global Rules"

# 2. MCP Config
create_symlink \
  "$DOTFILES_ROOT/config/devin/mcp/mcp_config.json" \
  "$HOME/.codeium/windsurf/mcp_config.json" \
  "MCP Configuration"

# 3. Unified Devin Configuration (hooks)
create_symlink \
  "$DOTFILES_ROOT/config/devin/hooks.json" \
  "$HOME/.config/devin/config.json" \
  "Unified Devin Configuration"

# 4. Global Skills
echo ""
echo "Setting up Global Skills..."

skills_dir="$DOTFILES_ROOT/config/devin/skills"
if [[ -d "$skills_dir" ]]; then
  for skill_file in "$skills_dir"/*.skill.md; do
    if [[ -f "$skill_file" ]]; then
      skill_name=$(basename "$skill_file" .skill.md)
      skill_target="$HOME/.config/devin/skills/$skill_name/SKILL.md"

      mkdir -p "$HOME/.config/devin/skills/$skill_name"
      backup_if_exists "$skill_target"
      [[ -L "$skill_target" ]] && rm "$skill_target"

      if ln -sf "$skill_file" "$skill_target"; then
        echo -e "${GREEN}✅ Skill: $skill_name${NC}"
      else
        echo -e "${RED}❌ Failed: $skill_name${NC}"
      fi
    fi
  done
else
  echo -e "${YELLOW}⚠️  No skills directory found at $skills_dir${NC}"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  Global Rules:  ~/.codeium/windsurf/memories/global_rules.md"
echo "  MCP Config:    ~/.codeium/windsurf/mcp_config.json"
echo "  Devin Config:  ~/.config/devin/config.json"
echo "  Skills:        ~/.config/devin/skills/*/"
echo ""
echo "Next steps:"
echo "  1. Restart Windsurf to load global rules"
echo "  2. Test with: /dotfiles-audit"
echo "  3. Edit rules via IDE → changes auto-tracked in git"
echo ""
echo "Verification:"
echo "  ls -la ~/.codeium/windsurf/memories/global_rules.md"
echo "  ls -la ~/.codeium/windsurf/mcp_config.json"
echo "  ls -la ~/.config/devin/config.json"
echo "  ls -la ~/.config/devin/skills/*/"
echo ""

# Optional verification
if [[ "${1:-}" == "--verify" ]]; then
  echo "Running verification..."
  echo ""

  errors=0

  if [[ -L "$HOME/.codeium/windsurf/memories/global_rules.md" ]]; then
    echo -e "${GREEN}✅ Global rules symlinked${NC}"
  else
    echo -e "${RED}❌ Global rules not symlinked${NC}"
    ((errors++))
  fi

  if [[ -L "$HOME/.codeium/windsurf/mcp_config.json" ]]; then
    echo -e "${GREEN}✅ MCP config symlinked${NC}"
  else
    echo -e "${RED}❌ MCP config not symlinked${NC}"
    ((errors++))
  fi

  if [[ -L "$HOME/.config/devin/config.json" ]]; then
    echo -e "${GREEN}✅ Devin config symlinked${NC}"
  else
    echo -e "${RED}❌ Devin config not symlinked${NC}"
    ((errors++))
  fi

  skill_count=$(find "$HOME/.config/devin/skills" -name "SKILL.md" -type l 2>/dev/null | wc -l)
  if [[ $skill_count -gt 0 ]]; then
    echo -e "${GREEN}✅ $skill_count skill(s) symlinked${NC}"
  else
    echo -e "${YELLOW}⚠️  No skills symlinked${NC}"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}🎉 All checks passed!${NC}"
  else
    echo -e "${RED}⚠️  $errors error(s) found${NC}"
    exit 1
  fi
fi
