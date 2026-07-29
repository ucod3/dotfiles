#!/usr/bin/env bats

setup() {
  REPO_ROOT="$BATS_TEST_DIRNAME/.."
  CLAUDE_WORKFLOW="$REPO_ROOT/.github/workflows/claude.yml"
  TESTING="$REPO_ROOT/docs/TESTING.md"
}

# A substring match starts runs from prose that merely quotes the trigger —
# documentation, handoff examples, and issue bodies all did so (issue #44).
@test "agent invocation requires the trigger at the start of the body" {
  grep -qF "startsWith(github.event.comment.body, '@claude')" "$CLAUDE_WORKFLOW"
  grep -qF "startsWith(github.event.review.body, '@claude')" "$CLAUDE_WORKFLOW"

  run grep -F "contains(github.event" "$CLAUDE_WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "agent invocation covers the comment, review-comment, and review journeys" {
  for event in issue_comment pull_request_review_comment pull_request_review; do
    grep -qF "github.event_name == '$event'" "$CLAUDE_WORKFLOW"
  done
}

# Issue bodies are prose that routinely quotes commands, so opening or being
# assigned an issue must not invoke the agent. Comment on the issue instead.
@test "opening an issue does not invoke the agent" {
  run grep -E '^  issues:' "$CLAUDE_WORKFLOW"
  [ "$status" -ne 0 ]

  run grep -F 'github.event.issue.body' "$CLAUDE_WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "the agent workflow keeps read-only repository permissions" {
  run grep -E '^\s+(contents|pull-requests|issues|actions): write' "$CLAUDE_WORKFLOW"
  [ "$status" -ne 0 ]

  grep -qF 'contents: read' "$CLAUDE_WORKFLOW"
}

@test "the invocation rule is documented for contributors" {
  grep -qF '### Agent workflows' "$TESTING"
  grep -qF '.github/workflows/claude.yml' "$TESTING"
  grep -qF 'skipped' "$TESTING"
}
