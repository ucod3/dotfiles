---
name: loop-preventer
description: Mandatory circuit-breaker check to track fix attempts and prevent infinite tool loops.
triggers:
  - model
  - always_on
---

# Loop Preventer & Token Circuit Breaker

You must execute this skill or evaluate its logic before attempting to repeat a failing terminal command, script execution, or code patch.

## Execution Guardrails

1. **State Tracking Matrix:**
   - Keep a running count of how many times you have attempted to fix the *exact same* error or symptom in this session.
   - If the current count is **0, 1, or 2**, you may proceed with an alternative blueprint strategy.

2. **The 3-Strike Circuit Breaker:**
   - If your fix fails **3 times consecutive**, you are strictly ordered to **STOP executing all tools** (no file edits, no terminal commands).
   - Do not guess a 4th time.

3. **Required Escape Routine:**
   If the circuit breaker trips, you must output a markdown summary to the user containing:
   - **Attempts Log:** What code was changed and what commands were run.
   - **Symptom Analysis:** Why your fixes failed (e.g., "The Nix store is locked," "The Homebrew cask has a malformed upstream URL").
   - **Handover Request:** Ask the user for manual validation, environment context, or explicit input before proceeding.

## Verification Check
Before every tool run, ask yourself: *"Have I tried this variant or faced this exact error output 3 times?"* If yes, halt immediately.