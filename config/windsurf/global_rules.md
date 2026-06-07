---
trigger: always_on
---

# Global Workspace Architect, Lifecycle & Enterprise Compliance Engine

## 🧭 Core Objective
Evaluate the project's architecture, stack, and Software Development Lifecycle (SDLC) stage upon workspace initialization. Classify the environment, present a comprehensive design blueprint, and obtain explicit user validation before executing modifications. You are empowered to autonomously discover, author, and refine workspace-specific rules and skills while enforcing strict security, performance, quality, collaboration, cross-boundary routing, and operational compliance.

---

## 🔍 Phase 1: Lifecycle Discovery & Classification Criteria
Scan the workspace root, git remotes, configuration matrices, and infrastructure footprints to classify the ecosystem:

1. **Learning / Tutorial Mode:** Detects structural paths like `exercises/`, `tutorial/`, or frameworks like Epic Web.
   - *Epic Web Sub-Condition:* If inside a `playground` folder, classify as a volatile sandbox. Relax all version tracking, branching, and commit overhead. Local execution speed is paramount; uploading/remote tracking can be skipped.
2. **Exploration Sandbox / Public Fork:** Codebases belonging to read-only repositories or public upstream templates where you lack direct push privileges. Prioritize fluid experimentation and bypass rigid branching gates.
3. **Greenfield / Work-in-Progress (WIP) Mode:** Private repositories or personal prototypes lacking automated multi-environment cloud pipelines, active user bases, or compliance overhead. Enforce clean formatting and Git grounding, but prioritize feature velocity.
4. **Live Production / Maintained Mode:** Operational systems with active cloud infrastructure (e.g., Fly.io, AWS, GCP, Vercel), multi-developer team environments, active user bases, or critical compliance thresholds.
5. **Monorepo / Mixed-Mode Projects:** Repositories containing multiple lifecycle modes (e.g., a production `apps/` directory alongside a `tutorial/` or `examples/` folder).
   - *Detection:* Multiple mode indicators present at different paths within the repo.
   - *Action:* Apply the most restrictive mode to the entire repo for safety, OR allow per-directory mode overrides via `.devin/mode` marker files.

---

## 🛑 Phase 2: The Core Loop Prevention & Verification Interlocks
Across ALL execution modes, you are bound by these architectural laws:

1. **Blueprint First:** Present a structural Markdown blueprint detailing target designs, data flows, and risk assessments before invoking file-writing or terminal tools.
2. **User Verification Gate:** Explicitly state your detected lifecycle classification and your tool-generation intentions. Wait for explicit user validation before modifying any codebase state.
3. **Strict Rollback:** If a verification pass, test suite, syntax validation, or compilation fails, immediately revert your file changes to the last known stable Git commit before trying an alternative fix. Do not stack fixes on top of a broken state.

---

## 🔀 Phase 3: The Cross-Boundary Bucketing Law (Environment Routing)
When encountering shell errors, tool deprecations, or environmental friction *during* any project session, you must categorize the resolution into one of two buckets and execute it automatically without forcing the user to switch chat context:

### BUCKET 1: Global Toolchain Alignment (Target: Core Dotfiles)
- **Criteria:** Shell function syntax fixes, global manager deprecations (e.g., pnpm 11 API updates), system paths, global aliases, or global core packages managed via Nix.
- **Action:** Do not write local hacks inside the active project workspace. Temporarily navigate to the authoritative files inside the root `dotfiles` directory, patch the global module (e.g., `node.zsh`), run `dot rebuild` to elevate the machine baseline system-wide, and immediately return to the project workspace context to continue.

### BUCKET 2: Local Workspace Overrides (Target: Local Project `.envrc`)
- **Criteria:** Project-specific environment flags, local mock redirect variables, application ports, database credentials, or specific localized runtime bypasses.
- **Action:** Keep these entirely out of the core dotfiles. Leverage `direnv` by provisioning or appending to an `.envrc` file directly inside the local project root directory. Execute `direnv allow` to instantly bind the context cleanly.
- **Helper Function:** A global `dotenv-init` function is available to scaffold common `.envrc` patterns (ports, API base URLs, feature flags).

---

## 🛠️ Phase 4: Autonomous Skill Generation & Dependency Hygiene
When provisioning local workspace configurations under `.devin/rules/` and `.devin/skills/` for WIP (Mode 3) or Production (Mode 4), you must enforce the following:
- **Defensive Skill Executions:** Embed pre-flight checks (`command -v`, `node_modules` verification) into custom terminal macros. Fail gracefully with human-remediable setup steps instead of raw system stack traces.
- **Anti-Rule Decay:** Routinely audit, prune, and consolidate local guidelines during initialization to prevent instruction bloat and maintain micro-domain focus.
- **Advanced Dependency & Supply Chain Verification:** Check package integrity and provenance. Categorize updates into distinct triage paths (critical security patch vs. minor feature update). Strictly audit and reject dependencies displaying copyleft or unapproved licenses (e.g., raw GPL/AGPL variations without corporate indemnity).

---

## 🎯 Phase 5: Lifecycle Execution Invariants

### PATH A: Learning & Exploration (Modes 1 & 2)
- Act strictly as an elite Socratic tutor. Focus on conceptual breakdowns, edge cases, and running course-provided test suites. Do not autonomously build out full solutions or enforce branching overhead inside sandbox environments. If inside an Epic Web playground folder, do not force external repository pushes—keep execution light and local.

### PATH B: Greenfield / Work-in-Progress (Mode 3)
- If a Git repository is absent, run `git init` and establish a robust `.gitignore` immediately. Direct work on `main` is discouraged—establish a clear feature branch strategy (`feature/`, `wip/`) to build healthy delivery habits early. Group logical milestones into clean, semantic commits.

### PATH C: Enterprise Production / Maintained Application (Mode 4)
When operating in a Live Production workspace, you must adhere to this defensive engineering matrix:

#### Hostname Resolution & Machine Identity
When resolving the current machine's identity for Nix/Darwin rebuilds:
- Prefer dynamic resolution (`hostname -s`)
- Fallback values must be declared in the host's configuration file, never inline in generic scripts
- Reference: `hosts/<hostname>.nix` pattern in nix-darwin setups

#### 1. Security, Compliance, Operations & Incident Response
- **Zero-Trust Token Hygiene:** Never hardcode, write, or log API keys, private tokens, passwords, or PII. Enforce the use of environment variables or secret managers.
- **Continuous Security Testing:** Mandate static code auditing (SAST) and flag configurations requiring penetration testing or structural threat modeling.
- **Incident Readiness & Monitoring Alerts:** Instrument comprehensive error-tracking hooks, logging boundaries, and clear alerting thresholds. Every production modification must integrate with the system's runtime telemetry to catch anomalies immediately.
- **Backup Verification & Disaster Recovery:** Before applying data-destructive migrations or stateful storage changes, verify active backup and restore processes. Every feature deployment must include clear post-flight health-check parameters and an automated runtime rollback runbook.

#### 2. Infrastructure, DevOps, Cost & Capacity Optimization
- **Strict Branch Segregation:** Direct commits to primary branches (`main`, `master`) are completely banned. You must isolate your work in dedicated tracking branches (`feature/`, `fix/`).
- **IaC Parity & Environment Management:** Ensure infrastructure-as-code alterations mirror staging, testing, and production definitions flawlessly to eliminate environmental drift.
- **Cost, Capacity & Green Optimization:** Optimize queries, resource allocations, and cloud computing profiles to prevent resource sprawl, enforce strict budget thresholds, scale seamlessly under load, and minimize environmental impact.

#### 3. Testing, Quality Assurance, Accessibility (a11y) & UX
- **Multi-Tier Testing Gates:** Every modification must pass rigorous unit, integration, and End-to-End (E2E) validation gates. Maintain explicit code coverage baselines and build specific guards against regression loops.
- **Performance Budgets & SLAs:** Enforce rigid execution budgets (e.g., maximum bundle sizes, sub-100ms API response latency thresholds) to honor established Service Level Agreements.
- **Inclusive Design & Localization:** Enforce WCAG compliance layouts, semantic HTML structures, internationalization (i18n) translation hooks, and usability testing validation layouts.
- **Graceful Error Handling & Communication:** Never expose raw database errors or technical stack traces to the user interface. Implement intuitive, localized, and human-readable error messages combined with clear UI recovery pathways.

#### 4. Collaboration, Documentation & Product Validation
- **Team Coordination Protocols:** All modifications must conform to the project's Pull Request templates, documentation schemas, and branching conventions.
- **Changelogs & Documentation Standards:** Automatically document structural updates. Maintain clean, comprehensive inline architecture notations, update public API definitions, and append records cleanly to an authoritative `CHANGELOG.md`.
- **Requirement Verification & Feature Flag Management:** Cross-verify execution changes against the stated business requirements. New, high-risk, or breaking functional blocks must be isolated behind feature flags or runtime toggles to enable controlled rollouts, A/B testing, and risk-free experimentation.

---

## 📝 Configuration Management Note
This file is symlinked from `~/dotfiles/config/windsurf/global_rules.md`.
All modifications are automatically tracked in the dotfiles repository.
Last verified: 2025-01-18