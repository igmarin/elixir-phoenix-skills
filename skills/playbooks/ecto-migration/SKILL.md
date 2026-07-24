---
name: ecto-migration
type: playbook
tags: [playbooks]
license: MIT
description: >
  Safe migration playbook with hard gates and HITL for production risk: plan locks/rollback →
  implement schema-only migration → migrate/rollback/re-migrate → never mix backfill →
  expand-contract for NOT NULL → suite green.
  Trigger: migration, ecto.migrate, add column, index concurrently, expand-contract.
metadata:
  version: "1.0.0"
  user-invocable: "true"
  entry_point: true
  phases: "1 Plan, 2 Implement, 3 Migrate cycle, 4 Verify"
  hard_gates: "Plan and rollback documented, No combined schema and data migrations, Migrate-rollback-migrate cycle green, Tests green and HITL approval"
  dependencies:
    source: self
    skills:
      - ecto-essentials
      - apply-ecto-conventions
---

# Ecto Migration Playbook

## HARD-GATE

- A migration plan and rollback story are documented before any migration is written.
- Schema changes and data backfill are never combined in the same migration.
- The `mix ecto.migrate` → `mix ecto.rollback` → `mix ecto.migrate` cycle must succeed.
- Tests must be green and HITL approval obtained for production-impacting locks.

## When to use

Any schema change: tables, columns, indexes, constraints.

## Atomic skills this playbook loads

| Skill | Path | Role |
|-------|------|------|
| `ecto-essentials` | `skills/database/ecto-essentials/` | Migrations/schemas |
| `apply-ecto-conventions` | `skills/database/apply-ecto-conventions/` | Repo/query conventions |

## Flow

```mermaid
flowchart TD
  A[Plan locks rollback impact] --> B[HITL if prod risk]
  B --> C[Write schema migration]
  C --> D[migrate rollback migrate]
  D --> E[Suite green]
  E --> F[Separate backfill migration if needed]
```

## Phases

### Phase 1 — Plan

Assess: lock risk, expand-contract need, rollback strategy, index concurrency.

**HUMAN-IN-THE-LOOP:** for production-impacting locks or multi-step expand-contract, present plan and wait for approval.

**HARD GATE — Plan:** rollback story documented.

### Phase 2 — Implement

- Schema change **or** data backfill — **never both** in one migration
- Indexes on FKs; reversible `change/0` when possible

### Phase 3 — Migrate cycle

```bash
mix ecto.migrate
mix ecto.rollback
mix ecto.migrate
```

**HARD GATE:** cycle succeeds.

### Phase 4 — Verify

```bash
mix test
```

Update schemas/typespecs if columns changed.

## Verification checklist

- [ ] Plan + rollback noted
- [ ] No combined schema+backfill
- [ ] migrate/rollback/migrate OK
- [ ] Tests green
- [ ] HITL for high-risk prod steps

## Error Recovery

Irreversible migration → stop; write compensating migration; do not force production.

## Output Style

Plan summary, migration paths, command results.
