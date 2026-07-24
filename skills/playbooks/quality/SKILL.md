---
name: quality
type: playbook
tags: [playbooks]
license: MIT
description: >
  Pre-PR quality loop with hard gates: mix format, credo, dialyzer, hex.audit, full tests →
  optional FCIS-safe refactor with characterization tests and HITL → docs/specs on public APIs.
  Trigger: before PR, quality sweep, production readiness, credo, dialyzer, refactor for PR.
metadata:
  version: "1.0.0"
  user-invocable: "true"
  entry_point: true
  phases: "1 Conventions, 2 Refactor optional, 3 Docs"
  hard_gates: "Quality commands exit 0, Refactor green tests and user approval, No simulated green gates"
  dependencies:
    source: self
    skills:
      - code-quality
      - credo-config
      - refactor-code
      - typespec-dialyzer
---

# Quality Playbook

## HARD-GATE

- All quality commands (`mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`, `mix hex.audit`, `mix test`) must exit 0 before a PR is opened.
- Any refactor requires green characterization tests and explicit user approval.
- No gate may be skipped or declared green from simulated output.

## When to use

Before opening a PR or when asked for a full quality/production-readiness pass.

## Atomic skills this playbook loads

| Skill | Path | Role |
|-------|------|------|
| `code-quality` | `skills/quality/code-quality/` | Complexity/duplication |
| `credo-config` | `skills/quality/credo-config/` | Credo setup |
| `refactor-code` | `skills/quality/refactor-code/` | Safe extractions |
| `typespec-dialyzer` | `skills/elixir-core/typespec-dialyzer/` | Specs/docs types |

## Flow

```mermaid
flowchart TD
  A[Run format credo dialyzer audit test] --> B{All green?}
  B -->|No| C[Fix violations]
  C --> A
  B -->|Yes| D{Complexity over threshold?}
  D -->|No| F[Docs and specs]
  D -->|Yes| E[HITL refactor plan + characterize]
  E --> F
  F --> G[PR ready]
```

## Complexity thresholds (Phase 2 trigger)

| Metric | Threshold |
|--------|-----------|
| Function length | > 20 lines |
| Parameters | > 4 |
| Module length | > 400 lines |
| Nesting | > 3 |
| Pipe chain | > 5 |

## Phases

### Phase 1 — Conventions

```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
mix hex.audit
mix test
```

**HARD GATE:** all commands exit 0 before Phase 2/PR.

### Phase 2 — Refactor (optional)

Only if thresholds exceeded.

1. Characterization test (must be green on current code).
2. **HUMAN-IN-THE-LOOP:** propose one extraction at a time; wait for approval.
3. Apply one change; re-run tests.
4. Prefer FCIS extractions (pure modules out of LiveViews/controllers/workers).

**If red:** revert last change; smaller step.

### Phase 3 — Documentation

- `@doc` + `@spec` on public APIs touched
- No PR until docs + Phase 1 gate hold

## Verification checklist

- [ ] Format / Credo / Dialyzer / audit / test green
- [ ] Refactors (if any) HITL-approved and characterized
- [ ] Public APIs documented
- [ ] No FCIS violations introduced (fat edges)

## Error Recovery

Fix failing tool first; never open PR with a red gate.

## Output Style

Command results table, refactor list, docs remaining.
