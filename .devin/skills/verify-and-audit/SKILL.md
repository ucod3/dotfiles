---
name: verify-and-audit
description: Use this skill automatically whenever a code modification, refactor, or feature implementation phase is completed to run local tests and ensure system stability.
---

### Verification Routine
1. Run Static Analysis: Open the terminal and execute `scripts/bin/validate` from the workspace root. Ensure it returns 0 errors.
2. Test Sourcing: Run a quick dry-run subshell to verify that all newly modified or decoupled zsh modules source without stderr noise.
3. Check Composite Hook: Ensure that `.git/hooks/pre-commit` correctly chains syntax validation and secret scanning functions seamlessly.

### Audit Routine
1. Check for exposed private credentials, personal tokens, or over-permissive local paths.
2. Verify that error handling outputs clean, user-friendly instructions instead of silent failures or raw stack traces.

Provide a clear markdown Verification Scorecard detailing the test results and a final PASS/FAIL status before marking the task complete.