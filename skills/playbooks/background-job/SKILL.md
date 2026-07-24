---
name: background-job
type: playbook
tags: [playbooks]
license: MIT
description: >
  Oban worker playbook with hard gates and HITL: design idempotency and error classes →
  failing worker test → thin perform/1 (FCIS edge) → retry/discard → failure tests → monitoring.
  Trigger: Oban, background job, worker, perform, enqueue, unique job.
metadata:
  version: "1.0.0"
  user-invocable: "true"
  entry_point: true
  phases: "Phase 1: Design, Phase 2: RED, Phase 3: HITL impl, Phase 4: Failure paths, Phase 5: Monitor"
  hard_gates: "Idempotency and error classification, Failing worker test, Thin perform/1, Failure paths tested, User approval and green suite"
  dependencies:
    source: self
    skills:
      - oban-essentials
      - testing-essentials
      - elixir-essentials
      - telemetry-essentials
---

# Background Job Playbook

## HARD-GATE

- Idempotency key and error classification are documented before implementation.
- A failing worker test exists and fails for the right reason before `perform/1` is written.
- `perform/1` is a thin edge: fetch IDs → pure core → return tagged tuple.
- Failure paths are tested; user approves the worker design.
- `mix format --check-formatted`, `mix credo --strict`, and the full `mix test` suite are green before the PR is opened.

## When to use

Adding or hardening Oban (or similar) background workers.

## Atomic skills this playbook loads

| Skill | Path | Role |
|-------|------|------|
| `oban-essentials` | `skills/infrastructure/oban-essentials/` | Worker patterns |
| `testing-essentials` | `skills/testing/testing-essentials/` | Oban.Testing |
| `elixir-essentials` | `skills/elixir-core/elixir-essentials/` | FCIS |
| `telemetry-essentials` | `skills/performance/telemetry-essentials/` | Metrics |

## Flow

```mermaid
flowchart TD
  A[Idempotency + error classes] --> B[Failing perform test]
  B --> C[HITL: approve worker design]
  C --> D[Thin perform/1 + context]
  D --> E[Retry discard unique tests]
  E --> F[Telemetry optional]
```

## Agent Phases

### Phase 1 — Design

Document: queue, args (IDs only), idempotency key, transient vs permanent errors.

**HARD GATE — Idempotency and error classification:**

- [ ] Queue, args (IDs only), idempotency key, and error classes are documented.
- [ ] Transient vs permanent errors are classified.

**If gate fails:** Revisit the design doc; do not write `perform/1` until the contract is clear.

### Phase 2 — RED

Worker test expecting success/cancel/error paths; must fail until implemented.

**HARD GATE — Failing worker test:**

- [ ] A worker test exists for success, cancel, and error paths.
- [ ] The test fails for the right reason before `perform/1` is written.

**If gate fails:** Adjust the test so it exercises missing behaviour, not a syntax/config mistake.

### Phase 3 — HITL impl

1. Propose `perform/1` as edge: fetch → domain → tuple.
2. **HUMAN-IN-THE-LOOP:** approve.
3. Implement; enqueue from **context**, not LiveView.

**HARD GATE — Thin perform/1:**

- [ ] `perform/1` fetches IDs, delegates to a pure core/domain function, and returns a tagged tuple.
- [ ] User approves the worker design before implementation.
- [ ] Enqueue happens from context, not LiveView.

**If gate fails:** Extract logic into a context or pure function; re-HITL the design.

### Phase 4 — Failure paths

Cover: not found → cancel; transient → error/retry; duplicate → unique.

**HARD GATE — Failure paths tested:**

- [ ] `not_found` path returns `{:cancel, _}` or equivalent.
- [ ] Transient errors are retried; permanent errors are discarded.
- [ ] Duplicate jobs are handled via `unique` options or idempotency key.

**If gate fails:** Add missing tests and handling for each failure class.

### Phase 5 — Monitor

Attach telemetry/logging for failures if production-bound.

**HARD GATE — User approval and green suite:**

- [ ] User approves the final worker design.
- [ ] `mix format --check-formatted`, `mix credo --strict`, and `mix test` pass.
- [ ] Telemetry/logging is attached for production failures.

**If gate fails:** Fix formatting, Credo, or test failures; re-HITL if the design changed.

## Verification checklist

- [ ] Idempotency plan
- [ ] Tests for success and failure classes
- [ ] HITL approval
- [ ] No large payloads in args
- [ ] Enqueue from context

## Error Recovery

Non-idempotent side effects → add guards/unique; re-test double perform.

## Output Style

```markdown
## Background Job Report

**Design:** <queue, args, idempotency key, error classes>
**Test command:** `<mix test command>`
**HARD-GATE results:**
- Idempotency and error classification: PASS / FAIL
- Failing worker test: PASS / FAIL
- Thin perform/1: PASS / FAIL
- Failure paths tested: PASS / FAIL
- User approval and green suite: PASS / FAIL
**Verdict:** APPROVE / REQUEST_CHANGES
```
