---
name: loop-preventer
description: Post-mortem procedure to run when the circuit breaker trips on a repeating error.
triggers:
  - model
---

# Loop preventer — escape routine

The threshold itself is defined once, as rule **R8** in `AGENTS.md` at the repo
root. Do not restate it here; this skill covers only *what to do* when it trips.

## When the breaker trips

Stop executing tools — no file edits, no terminal commands. Then output a
markdown post-mortem containing:

- **Attempts log** — what you changed and what commands you actually ran.
- **Evidence** — the real output you observed, not your interpretation of it.
  Quote the error. If you never saw the failing output directly, say so.
- **Root blocker** — what you believe is actually preventing progress (e.g.
  "the Nix store is locked", "the cask's upstream URL 404s", "this needs a
  credential I don't have").
- **Handover** — three concrete options for the user, and what input you need.

## Before each retry

Ask: *have I already faced this exact error output?* Track the count honestly.
Re-running a command with a cosmetic change is still a repeat attempt.
