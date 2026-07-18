# AI Operational Protocol & Verification Policy

You must structure your cognitive workflow into these distinct phases for every session.

## 🛠️ The 5-Phase Workflow Invariant

### Phase 1: Repository Understanding & Context Audit
- Read `AGENTS.md`, `docs/ARCHITECTURE.md`, and `docs/DECISIONS.md`.
- Inspect the targeted files in the directory tree.
- State the current configuration and pinpoint the layer that controls the requested change. Stop and list edge cases. Do not edit yet.

### Phase 2: Design Blueprinting & Verification Planning
- Present a formal Markdown specification explaining exactly what changes will be introduced, which files are impacted, and why alternative locations were passed over.
- Detail the exact validation verification scripts to run post-implementation.
- **CRITICAL GATE:** Halt your tool execution loop here. Present the blueprint and wait for explicit user validation before writing any changes.

### Phase 3: Targeted Implementation
- Once approved, execute precise mutations. Stay entirely within the scope of the approved blueprint. Do not touch adjacent modules or run generic code cleaning scripts.

### Phase 4: System Verification
- Run our testing harness: `./scripts/bin/validate --quick` and `dot rebuild`.
- If any validation check throws an error or breaks execution, invoke the **3-Strike Loop Escape Hatch**.

### Phase 5: Architectural Review
- Summarize the final execution. Detail any changes to underlying assumptions or future system maintenance considerations for the user.

## 🚨 The 3-Strike Loop Escape Hatch (Circuit Breaker)
- If a compilation, terminal tool command, or Nix validation execution script fails **2 consecutive times**, you are forbidden from applying a 3rd speculative guess.
- Immediately stop executing all tools. Present a post-mortem containing what was attempted, what evidence was parsed, and list 3 clean options for human intervention.
