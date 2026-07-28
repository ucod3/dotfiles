# AI Collaboration Contract

## Purpose

This document defines a vendor-neutral workflow for humans and AI agents working
on the same project. It is designed to be copied into another repository and
adapted through that project's own agent contract.

The workflow has three goals:

1. preserve the approved task instead of expanding it whenever a new concern is
   discovered;
2. ensure findings survive outside a chat session; and
3. give consequential changes an independent review before they are accepted.

Humans and agents follow the same evidence, scope, and handoff rules. AI product,
model, vendor, subscription-plan, and user-interface details do not belong in
this contract.

## Project adapter

This file does not replace the repository's product, architecture, safety, or
validation rules. Before working, identify:

- the canonical project contract, usually `AGENTS.md`;
- the product or requirements authority;
- the roadmap or current tracking issue;
- the architecture and decision records;
- the primary validation command;
- the repository's branch, publication, and approval rules.

Those project-local sources outrank this reusable workflow.

## Roles

Roles describe responsibilities, not particular tools. One participant may hold
more than one role, but a consequential change should not be implemented and
independently approved by the same participant.

### Decision owner

Owns product direction, scope expansion, safety trade-offs, destructive actions,
publication, and other decisions the project reserves for a human or designated
maintainer.

### Coordinator

Keeps the task aligned with its approved outcome, assigns work, tracks durable
records, and confirms that the handoff is complete.

### Implementer

Changes only the approved scope, validates the result, and records unexpected
findings without silently absorbing them into the implementation.

### Reviewer

Independently checks the diff and evidence. The reviewer may recommend fixing a
finding now, recording it for later, or rejecting it as incorrect or irrelevant.

### Recorder

Ensures decisions, findings, and follow-up work are stored in the appropriate
durable project system. This responsibility belongs to whoever discovers the
information until a record exists.

## Standard task flow

1. **Orient** — read the project adapter sources and inspect the current state.
2. **Define** — state the intended outcome, boundaries, compatibility effects,
   files or components involved, and validation plan.
3. **Approve** — obtain whatever approval the project requires.
4. **Isolate** — use a dedicated branch or other project-approved workspace.
5. **Implement** — make the smallest independently reviewable change.
6. **Validate** — run the project-defined checks and confirm they exercised the
   intended behavior.
7. **Review** — inspect the diff and use an independent reviewer where required.
8. **Publish** — commit, push, open, merge, deploy, or activate only within the
   authority already granted.
9. **Handoff** — provide the structured record defined below.

## Unexpected findings

An unexpected finding must be recorded before an agent pauses, hands off, or
asks what to do next. A chat message alone is not a durable record.

### Classify first

**In-scope correction**

The finding is an ordinary defect directly preventing the approved outcome, and
fixing it does not change product behavior, safety boundaries, compatibility,
or authority. Fix it, validate it, and include it in the handoff.

**Non-blocking follow-up**

The approved task remains safe and truthful without the change. Record the
finding, link the record in the handoff, and finish the approved task. Do not
expand the current diff.

**Blocking finding**

The task cannot safely or truthfully continue. Examples include possible data
loss, secret exposure, destructive behavior, a false product claim, incompatible
architecture, or a required decision outside granted authority. Record the
evidence, preserve the working state, and stop before the risky action.

**Uncertain finding**

Evidence is incomplete or reviewers disagree. Record what is known, what remains
unknown, and how it could be verified. Do not present the concern as established
fact.

### Durable record routing

| Finding | Durable location |
| --- | --- |
| Specific to the current change | Pull-request comment or review thread |
| Follow-up within an existing workstream | Existing tracking issue |
| Independent defect or feature | New issue |
| Long-term product sequence | Roadmap, after acceptance |
| Architectural decision and trade-off | Decision record, after approval |
| Temporary status or raw investigation | Task notes or chat; not durable memory |

A record should include:

- concise title;
- observed evidence;
- user or system impact;
- affected paths or components;
- whether it blocks the current task;
- reasonable options and trade-offs;
- recommended next step;
- links to the current change and related records.

## Independent review

Independent review is required when a change:

- alters architecture, compatibility, security, privacy, or a safety boundary;
- publishes data or changes external state;
- performs destructive or difficult-to-reverse actions;
- resolves an unexpected blocking finding;
- changes a product promise or accepted decision; or
- is otherwise marked for independent review by the project.

The reviewer evaluates the evidence rather than simply agreeing with the
implementer. The review result should be one of:

- **accept** — the implementation and evidence are sufficient;
- **revise** — specific changes are required in the current task;
- **defer** — the current task may finish and a durable follow-up exists;
- **reject finding** — evidence shows the concern is incorrect or irrelevant;
- **decision required** — the designated decision owner must choose.

The reviewer does not enlarge the implementation merely because an improvement
is possible.

## Workspace isolation

Every active implementation has one owning branch. Participants must not edit
the same dirty working directory concurrently.

When work happens sequentially, a normal feature branch is sufficient. When
several participants need simultaneous repository access, separate Git
worktrees are a useful isolation option:

- one directory and branch per implementation;
- no branch switching underneath another participant;
- shared Git history without shared uncommitted files;
- explicit handoff by commit, branch, or pull request.

Worktrees are not mandatory. A project should introduce them through a separate
guide and rehearsal so contributors understand creation, branch ownership,
cleanup, and recovery before relying on them.

## Structured handoff

Every implementation handoff should report:

```text
Outcome:
  What is now true?

Scope:
  What changed, and what deliberately did not change?

Workspace:
  Repository, branch, commit, and pull request.

Validation:
  Commands or checks run, results, and anything not verified.

Unexpected findings:
  Finding, classification, durable-record link, and blocker status.
  Write "None" when there were none.

Decisions:
  Decisions already made and decisions still required.

Next action:
  The exact safe next step and who owns it.
```

The receiving participant should be able to continue from the handoff and its
links without reconstructing the previous chat.

## Failure and circuit breakers

Follow the project's retry limit. If none exists, stop after three consecutive
failures against the same underlying error.

At the stop point:

- preserve the last known-good state;
- record the attempted approaches and exact evidence;
- distinguish environmental failure from implementation failure;
- avoid trying a broader rewrite merely to escape the error; and
- hand off clear verification options.

## Copying this contract

When adopting this document in another project:

1. copy it without adding vendor-specific role names;
2. add a short pointer from that project's canonical agent contract;
3. keep project commands and safety rules in the project adapter sources;
4. choose the durable issue, review, roadmap, and decision systems;
5. define publication and approval authority; and
6. rehearse the handoff with a small, reversible task before relying on it for
   consequential work.

The document should evolve by improving the shared workflow, not by accumulating
the history of one project or one tool.
