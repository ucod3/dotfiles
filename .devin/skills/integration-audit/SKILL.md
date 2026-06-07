---
name: integration-audit
description: Automatically audit alignment between global_rules.md references and dotfiles implementations. Run this whenever global rules are updated or dotfiles structures change.
---

### Integration Audit Routine

This skill verifies that the dotfiles repository correctly implements all referenced patterns from the global workspace rules.

#### 1. Cross-Boundary Bucketing Compliance

**Check Bucket 1 (`dot rebuild`) implementation:**
```bash
# Verify dot dispatcher exists and handles rebuild
grep -q "rebuild" "${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/dot" && echo "✓ dot rebuild available" || echo "✗ dot rebuild missing"

# Verify rebuild script exists and uses hostname resolution
[[ -x "${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/rebuild" ]] && echo "✓ rebuild script executable" || echo "✗ rebuild script missing"
```

**Check Bucket 2 (`dotenv-init`) implementation:**
```bash
# Verify dotenv-init function exists in utils.zsh
grep -q "^dotenv-init()" "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules/utils.zsh" && echo "✓ dotenv-init function exists" || echo "✗ dotenv-init missing"

# Verify it's documented
grep -q "dotenv-init" "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules/utils.zsh" && echo "✓ dotenv-init documented" || echo "✗ dotenv-init undocumented"
```

#### 2. Hostname Resolution Compliance

**Check for hardcoded fallbacks in generic scripts:**
```bash
# Search for hardcoded hostname fallbacks outside host configs
grep -r "Usmans-M4Pro\|fallback.*hostname" "${DOTFILES_ROOT:-$HOME/dotfiles}/scripts/bin/" 2>/dev/null && echo "✗ Hardcoded hostname fallback detected" || echo "✓ No hardcoded hostnames in scripts"
```

**Verify hosts/ directory pattern:**
```bash
[[ -d "${DOTFILES_ROOT:-$HOME/dotfiles}/hosts" ]] && ls "${DOTFILES_ROOT:-$HOME/dotfiles}/hosts/"*.nix 2>/dev/null | grep -q ".nix" && echo "✓ hosts/ directory with .nix configs" || echo "✗ hosts/ pattern missing"
```

#### 3. Lifecycle Mode Support

**Check for monorepo mode detection:**
```bash
# Verify .devin/mode marker file support
grep -q "\.devin/mode" "${DOTFILES_ROOT:-$HOME/dotfiles}/.devin/rules/"*.md 2>/dev/null && echo "✓ .devin/mode referenced" || echo "⚠ .devin/mode not yet implemented"
```

**Verify Epic Web detection exists:**
```bash
grep -q "epic-detect\|epicshop" "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules/workshop.zsh" && echo "✓ Epic Web detection implemented" || echo "✗ Epic Web detection missing"
```

#### 4. Rules & Skills Sync

**Check local guardrail extends global:**
```bash
grep -q "Global Workspace Architect\|global_rules" "${DOTFILES_ROOT:-$HOME/dotfiles}/.devin/rules/plan-and-execute-guardrail.md" && echo "✓ Local rule references global" || echo "⚠ Local rule lacks global reference"
```

**Verify skills are tracked:**
```bash
cd "${DOTFILES_ROOT:-$HOME/dotfiles}" && git ls-files .devin/skills/ | grep -q "SKILL.md" && echo "✓ Skills are git-tracked" || echo "✗ Skills not tracked"
```

#### 5. Nix Purity Checks

**Verify no builtins.getEnv:**
```bash
grep -r "builtins.getEnv\|getEnv" "${DOTFILES_ROOT:-$HOME/dotfiles}/"*.nix "${DOTFILES_ROOT:-$HOME/dotfiles}/nix/" 2>/dev/null && echo "✗ builtins.getEnv found (impurity)" || echo "✓ No builtins.getEnv"
```

**Check for hardcoded home paths:**
```bash
grep -r "/Users/\|/home/" "${DOTFILES_ROOT:-$HOME/dotfiles}/config/zsh/modules/" 2>/dev/null | grep -v "\$HOME\|DOTFILES_ROOT" && echo "✗ Hardcoded paths detected" || echo "✓ No hardcoded home paths"
```

### Audit Scorecard Template

```markdown
## Integration Audit Results

| Check | Status | Notes |
|-------|--------|-------|
| Bucket 1: dot rebuild | ✅/❌ | |
| Bucket 2: dotenv-init | ✅/❌ | |
| Hostname Resolution | ✅/❌ | |
| Monorepo Mode Support | ✅/❌ | |
| Epic Web Detection | ✅/❌ | |
| Rules Sync | ✅/❌ | |
| Skills Tracked | ✅/❌ | |
| Nix Purity | ✅/❌ | |

**Overall:** ✅ All checks pass / ❌ Needs attention
```

### When to Run

- After modifying global_rules.md or local .devin/rules/
- When adding new cross-boundary patterns
- Before committing structural dotfiles changes
- When global rules reference new dotfiles capabilities that may not exist yet

Provide a clear markdown Integration Scorecard with PASS/FAIL for each check.
