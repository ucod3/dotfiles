# AI Task Protocol

## Purpose

This document lets a human give a short, natural-language task such as:

```text
Review PR #42
Continue issue #39
Fix PR #42
Prepare a handoff
```

The participant should be able to start from the repository and its durable
records without requiring the human to copy the previous chat or construct a
tool-specific prompt.

This protocol defines how to interpret a task. It does not replace the
repository's product, architecture, safety, validation, approval, or
collaboration rules.

## Project adapter

Before acting, read the project's canonical agent contract and the sources it
identifies. At minimum, discover:

- the product or requirements authority;
- the current tracking issue;
- architecture and decision records relevant to the target;
- the primary validation command;
- branch and workspace ownership;
- publication, merge, deployment, activation, and deletion authority; and
- the durable system used for issues, reviews, decisions, and handoffs.

Project-local instructions outrank this reusable protocol.

## Start every task from durable state

1. Identify the requested **verb** and **target**.
2. Read the target and its linked records.
3. Inspect its latest structured handoff, unresolved review threads, checks,
   branch, commits, and current status.
4. Confirm the task's existing scope and the authority already granted.
5. Inspect the working tree before editing.
6. Continue from evidence in the repository and its collaboration system, not
   from assumptions about a previous chat.

If the latest handoff is missing or incomplete, reconstruct only what the
durable evidence supports and report the gap. Do not invent approval or scope.

## Task verbs and safe defaults

| Request | Default meaning | May edit? |
| --- | --- | --- |
| `Review PR #N` | Review the change, checks, unresolved threads, and stated scope. Record findings on the PR and leave a structured handoff. | No |
| `Audit PR #N` | Independently evaluate the completed implementation against its issue, accepted decisions, diff, validation, safety boundaries, and product contract. Record the verdict and findings on the PR. | No |
| `Review issue #N` | Review whether the issue is clear, correctly scoped, supported by evidence, and ready for its proposed next action. Record findings on the issue and leave a structured handoff. | No |
| `Review <document>` | Review the named document against its authorities and current project state. Report findings without rewriting it. | No |
| `Continue PR #N` | Resume the PR's already-approved objective from its latest durable handoff. | Yes, only within existing authority |
| `Continue issue #N` | Resume the issue's next approved implementation slice. If the issue is exploratory or lacks implementation approval, remain read-only. | Only when already authorized |
| `Fix PR #N` | Address actionable findings within the PR's approved scope, validate, and update the handoff. | Yes |
| `Implement issue #N` | Implement the issue's accepted scope using the project workflow. For tracked changes, create or update a linked PR and put the implementation handoff there. | Yes |
| `Explore <topic>` | Gather evidence, compare options, record conclusions, and recommend a next step. | No implementation |
| `Prepare a handoff` | Reconstruct and record the current outcome, workspace, validation, findings, decisions, and exact next action. | Only the durable handoff record |

Words such as `review`, `inspect`, `audit`, `assess`, and `explain` are read-only
unless the same request separately authorizes changes.

Words such as `implement`, `fix`, and `continue` authorize only the named scope.
They do not imply authority to merge, publish, deploy, activate, delete, migrate
live data, or broaden a product decision.

## Resolve the target

- `PR #N` means that pull request in the current repository.
- `issue #N` means that issue in the current repository.
- A named document means the tracked file with that name or path.
- `current PR` means the pull request for the checked-out branch.

Use read-only discovery to resolve a missing repository name, current branch, or
linked record. If multiple destructive or writable targets remain plausible,
stop and ask rather than choosing one.

## Choose the durable work record

Use the record that matches the work performed:

| Work performed | Primary durable record |
| --- | --- |
| Explore, refine, or review a proposed task | Issue comment |
| Implement tracked code or documentation | Pull request linked to the issue |
| Review or audit an implementation | Pull-request review or comment |
| Find unrelated follow-up work | Separate issue |
| Accept a lasting architecture trade-off | Project decision record |

A read-only issue review does not need an empty pull request. If implementation
produces a diff, the pull request becomes the implementation and handoff record;
the issue remains the objective, accepted scope, and decision record.

Link the issue and pull request in both directions when the collaboration system
does not do so automatically. The human should be able to transfer work by
providing only the identifier:

```text
Implement issue #41
Audit PR #42
Fix PR #42
Re-review PR #42
```

Do not require copied chat output when the participant can read the durable
record directly.

## Review protocol

A review must:

1. read the target's objective, diff or proposal, linked authorities, checks,
   prior findings, and latest handoff;
2. distinguish correctness defects from optional improvements;
3. classify unexpected findings using the collaboration contract;
4. record actionable findings in the target's durable review system;
5. avoid editing code or documents; and
6. finish with the structured handoff.

When the review comment itself contains the handoff, write:

```text
Durable record: current PR comment
```

or:

```text
Durable record: current issue comment
```

Do not say that no durable record exists after publishing the current comment.

## Continuation protocol

Before continuing implementation:

1. read the objective and latest structured handoff;
2. inspect unresolved review threads and failing checks;
3. confirm the owning branch and clean or intentionally staged working state;
4. verify that implementation was already approved;
5. make the smallest change that advances the approved outcome;
6. validate using the project-defined command; and
7. update the durable record before pausing or transferring ownership.

A receiving participant should not need a transcript from the previous
participant. The branch, commits, pull request or issue, checks, and handoff are
the transfer mechanism.

## Implementation and independent audit

For a scoped implementation:

1. the implementer reads the issue and accepted decisions;
2. the implementer creates or owns one branch, makes the change, validates it,
   and opens or updates the linked pull request;
3. the implementer posts the structured handoff on that pull request;
4. an independent reviewer receives `Audit PR #N` and reads the linked issue,
   diff, checks, review history, and handoff;
5. the reviewer records one verdict from `docs/AI_COLLABORATION.md` on the pull
   request without editing the implementation;
6. when revision is required, an implementer receives `Fix PR #N`; and
7. merge, deployment, or activation follows only after the required review and
   authority are present.

Roles are independent of product, model, vendor, or cost. A project may assign
routine, well-bounded implementation to one participant and reserve ambiguous,
architectural, security-sensitive, or final acceptance work for another. Every
participant still follows the same evidence, validation, safety, and handoff
rules.

## Authorization boundaries

Read-only discovery is allowed when it is necessary to understand the named
task. Writes must remain within the authority conveyed by the task verb, the
target's accepted scope, and the project contract.

Never infer permission to:

- merge or close a pull request;
- push or publish changes;
- deploy or activate a system;
- delete branches, files, data, or external resources;
- expose private information;
- change an accepted product or architecture decision; or
- absorb an unrelated finding into the current implementation.

If the project records standing authority for an action, follow that record and
cite it in the handoff. Otherwise request explicit approval.

## Durable findings and handoff

Record an unexpected finding before asking what to do next. Route it according
to `docs/AI_COLLABORATION.md`; do not turn memory files or chat transcripts into
project logs.

End every review, implementation, or transfer with:

```text
Outcome:
  What is now true?

Scope:
  What changed, and what deliberately did not change?

Workspace:
  Repository, branch, commit, and pull request or issue.

Validation:
  Checks run, results, and anything not verified.

Unexpected findings:
  Finding, classification, durable-record link, and blocker status.
  Write "None" when there were none.

Decisions:
  Decisions already made and decisions still required.

Next action:
  The exact safe next step and who owns it.

Durable record:
  The current PR or issue comment, or a direct link to another record.
```

Publish this handoff to the current pull request or issue when access permits,
then give the human a concise summary. If publication is unavailable, state
that limitation and provide the complete handoff for the human to post.

## Worktrees and simultaneous participants

This protocol does not require a worktree for sequential work. A normal feature
branch and durable handoff are sufficient when one participant stops before
another starts.

Use separate worktrees when multiple participants need simultaneous local
access. Each worktree must have one owning branch. Worktrees isolate uncommitted
files and branch changes; they do not replace commits, pull requests, validation,
or handoffs.

## Copying this protocol

To reuse this workflow in another project:

1. copy this document and `docs/AI_COLLABORATION.md`;
2. add concise pointers from that project's canonical agent contract;
3. keep project-specific commands and authority in the project adapter;
4. select the durable issue and review systems; and
5. rehearse both `Review issue #N` and `Continue issue #N` with a small,
   reversible task.

Keep the protocol vendor-neutral. Product names, model names, subscription
limits, and interface-specific instructions belong outside the reusable
contract.
