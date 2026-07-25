---
name: dotfiles-audit
description: Verify dotfiles environment health from any workspace. Checks that ~/dotfiles is present, commands work, and global patterns from global_rules.md are implemented.
triggers:
  - user
  - model
  - always_on
---

# Dotfiles Environment Audit

Run this from any workspace to verify your dotfiles development environment is healthy and aligned with global workspace rules.

## Audit Checks

### 1. Dotfiles Repository Presence

Verify the dotfiles repo exists and is accessible:

```bash
if [[ -d "$HOME/dotfiles" ]]; then
  echo "✅ Dotfiles directory exists: $HOME/dotfiles"
  cd "$HOME/dotfiles" && git log --oneline -1
else
  echo "❌ Dotfiles not found at $HOME/dotfiles"
  echo "   Install with: curl -fsSL https://raw.githubusercontent.com/ucod3/dotfiles/main/install.sh | bash"
  exit 1
fi
```

### 2. Core Commands Availability

Check that essential commands are in PATH:

```bash
command -v dot >/dev/null 2>&1 && echo "✅ dot command available" || echo "❌ dot command missing (add to PATH)"
command -v pnpm >/dev/null 2>&1 && echo "✅ pnpm available" || echo "❌ pnpm missing"
command -v direnv >/dev/null 2>&1 && echo "✅ direnv available" || echo "⚠️  direnv not installed (optional for .envrc)"
```

### 3. Dot Dispatcher Subcommands

Verify the `dot` dispatcher and its subcommands work:

```bash
DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/dotfiles}"
[[ -x "$DOTFILES_ROOT/scripts/bin/dot" ]] && echo "✅ dot dispatcher executable" || echo "❌ dot dispatcher missing"
[[ -x "$DOTFILES_ROOT/scripts/bin/rebuild" ]] && echo "✅ dot rebuild available" || echo "❌ dot rebuild missing"
[[ -x "$DOTFILES_ROOT/scripts/bin/validate" ]] && echo "✅ dot validate available" || echo "❌ dot validate missing"
[[ -x "$DOTFILES_ROOT/scripts/bin/update" ]] && echo "✅ dot update available" || echo "❌ dot update missing"
```

### 4. Global Rules Alignment (Bucket Checks)

Verify cross-boundary bucketing patterns from global_rules.md:

**Bucket 1: Global Toolchain (dot rebuild)**
```bash
if grep -q "dot rebuild" "$HOME/dotfiles/scripts/bin/dot" 2>/dev/null; then
  echo "✅ Bucket 1: dot rebuild pattern implemented"
else
  echo "❌ Bucket 1: dot rebuild not found in dispatcher"
fi
```

**Bucket 2: Local Overrides (dotenv-init)**
```bash
if grep -q "^dotenv-init()" "$HOME/dotfiles/config/zsh/modules/utils.zsh" 2>/dev/null; then
  echo "✅ Bucket 2: dotenv-init function available"
  echo "   Usage: dotenv-init [node|api|db]"
else
  echo "❌ Bucket 2: dotenv-init function missing"
fi
```

### 5. Zsh Module Health

Check that zsh modules source without errors:

```bash
cd "$HOME/dotfiles"
for module in config/zsh/modules/*.zsh; do
  if zsh -c "source $module 2>/dev/null" 2>/dev/null; then
    echo "✅ $(basename $module) sources cleanly"
  else
    echo "❌ $(basename $module) has errors"
  fi
done
```

### 6. Nix/Darwin System Health

Check if the system can evaluate (quick check, no rebuild):

```bash
cd "$HOME/dotfiles"
if nix flake check --no-build 2>/dev/null | grep -q "warning\|error"; then
  echo "⚠️  Nix flake has warnings (run 'dot validate' for details)"
else
  echo "✅ Nix flake evaluates cleanly"
fi
```

### 7. Skills and Rules Sync

Verify local dotfiles skills are present and tracked:

```bash
cd "$HOME/dotfiles"
if [[ -f ".devin/skills/verify-and-audit/SKILL.md" ]]; then
  echo "✅ verify-and-audit skill present"
else
  echo "⚠️  verify-and-audit skill missing"
fi

if git ls-files .devin/skills/ 2>/dev/null | grep -q "SKILL.md"; then
  echo "✅ Skills are git-tracked"
else
  echo "⚠️  Skills not yet committed"
fi
```

### 8. Pre-commit Hook

Check git hooks are installed:

```bash
if [[ -x "$HOME/dotfiles/.git/hooks/pre-commit" ]]; then
  echo "✅ Pre-commit hook installed"
else
  echo "⚠️  Pre-commit hook missing (run: dot hooks)"
fi
```

## Scorecard Output

Provide a markdown summary:

```markdown
## Dotfiles Audit Results

| Check | Status |
|-------|--------|
| Repository Present | ✅/❌ |
| Core Commands | ✅/❌ |
| Dot Dispatcher | ✅/❌ |
| Bucket 1 (dot rebuild) | ✅/❌ |
| Bucket 2 (dotenv-init) | ✅/❌ |
| Zsh Modules | ✅/❌ |
| Nix Health | ✅/❌ |
| Skills Tracked | ✅/❌ |
| Pre-commit Hook | ✅/❌ |

**Status:** ✅ All systems operational / ⚠️ Needs attention / ❌ Critical issues

**Next Steps:**
- If ❌: Run `dot validate` in ~/dotfiles for detailed diagnostics
- If ⚠️: Review warnings above
- If ✅: Environment is healthy
```

## When to Run

- **Starting a new project:** Verify dotfiles are available before beginning work
- **After dotfiles updates:** Ensure new patterns (like dotenv-init) are working
- **Debugging issues:** Check if environment drift is causing problems
- **Switching machines:** Quick health check on a new Mac

## Invocation

```
/dotfiles-audit
```

Or let the model invoke it automatically when:
- Shell commands fail unexpectedly
- Dotfiles patterns are referenced but may not be implemented
- Environment inconsistencies are suspected
