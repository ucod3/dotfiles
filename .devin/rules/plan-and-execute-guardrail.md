---
trigger: always_on
---

# Repository contract

Read [`AGENTS.md`](../../AGENTS.md) at the repo root and treat it as
authoritative. It is the single vendor-neutral source for the repo layout, the
`dot` CLI, hard rules **R1–R8** (including the blueprint gate, strict rollback,
the 3-strike circuit breaker, and the `builtins.getEnv` exception), the
workflow, and the definition of done.

Do not restate those rules here. Four vendor files previously carried
overlapping copies that drifted — one even specified a different strike count.
See ADR-008.

## Devin-specific

- Anything under `.devin/` (rules, skills, workflows) MUST be staged and
  committed alongside the work it supports. Rules that live only in an untracked
  file do not apply on another machine, and `dot validate` fails on untracked
  agent config.
