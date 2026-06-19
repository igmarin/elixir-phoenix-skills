---
name: ecto-migration
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates safe database migrations with hard gates: plan migration assessing lock behavior, rollback strategy, and performance impact → write and test migration with migrate/rollback/re-migrate idempotent cycle → never combine schema change and data backfill in one migration → use expand-contract for column changes (add nullable→backfill→enforce NOT NULL in separate migrations) → verify full test suite passes; phases planning→implementation→verification→deployment. Use when adding tables, columns, indexes, or modifying database schema. Trigger: database migration, schema change, add column, create table, modify index, ecto migration, Ecto.Migration.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when planning, implementing, or reviewing database migrations"
  phases: "Phase 1: Migration Planning, Phase 2: Implementation, Phase 3: Verification, Phase 4: Deployment"
  hard_gates: "Plan Approved, Idempotent Cycle Verified, Test Suite Passes, Rollback Ready"
  dependencies:
    - source: self
      skills: [ecto-essentials, ecto-changeset-patterns, testing-essentials]
  keywords: elixir, phoenix, ecto, migration, database, schema, postgresql, rollback
---
# Ecto Migration Persona

Orchestrates safe Ecto migrations with idempotent cycles, rollback planning, and production deployment safety.

## Agent Phases

### Phase 1: Migration Planning

**Steps:**
1. **Define the change** — Identify the exact schema modification required.
2. **Assess lock behavior** — Does the change acquire an ACCESS EXCLUSIVE lock? If so, how long will it hold on the target table size?
3. **Plan rollback** — Define the exact inverse operation for `down/0`.
4. **Classify the change:**
   - **Safe** (instant metadata-only): adding nullable column, creating table, creating index concurrently
   - **Risky** (table rewrite): changing column type, adding NOT NULL on existing column, renaming column
   - **Dangerous** (long lock): adding foreign key without validation, dropping column
5. **Expand-contract strategy for risky changes:**
   - Step 1: Add new column/table (nullable)
   - Step 2: Backfill data (separate migration or script)
   - Step 3: Enforce constraint (NOT NULL, unique, etc.)
   - Step 4: Remove old column/table (optional, later)

**HARD GATE — Plan Approved:**
- [ ] Change scope defined
- [ ] Lock impact assessed
- [ ] Rollback defined
- [ ] Change classified (safe/risky/dangerous)
- [ ] Expand-contract steps planned for risky changes

**If gate fails:** Clarify the schema change plan before implementing.

---

### Phase 2: Implementation

**Steps:**
1. Generate migration: `mix ecto.gen.migration <descriptive_name>`.
2. Implement `up/0` (or `change/0` for reversible migrations).
3. Implement `down/0` for explicit rollback.
4. Apply **database/ecto-essentials** for migration conventions.
5. Apply **database/ecto-changeset-patterns** if migrations involve data transformations.

**Idempotent cycle test:**
```bash
# Roll back
mix ecto.rollback

# Migrate up
mix ecto.migrate

# Roll back again
mix ecto.rollback

# Migrate up again
mix ecto.migrate
```

All four steps must succeed without errors.

**HARD GATE — Idempotent Cycle Verified:**
- [ ] `mix ecto.rollback` succeeds
- [ ] `mix ecto.migrate` succeeds
- [ ] Second rollback succeeds
- [ ] Second migrate succeeds
- [ ] No data loss on rollback (for safe migrations)

**If gate fails:** Fix the migration's `up`/`down` before proceeding.

### Migration Examples

**Add nullable column** (safe):
```elixir
defmodule MyApp.Repo.Migrations.AddPublishedAtToPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :published_at, :utc_datetime
    end
  end

  def down do
    alter table(:posts) do
      remove :published_at
    end
  end
end
```

**Add NOT NULL column with expand-contract** (risky):
```elixir
# Step 1: Add nullable column
defmodule MyApp.Repo.Migrations.AddStatusToPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :status, :string, default: "draft"
    end
  end

  def down do
    alter table(:posts) do
      remove :status
    end
  end
end

# Step 2: Backfill (separate migration or mix task)
defmodule MyApp.Repo.Migrations.BackfillPostStatus do
  use Ecto.Migration

  def up do
    execute("UPDATE posts SET status = 'draft' WHERE status IS NULL")
  end

  def down do
    # No-op — backfilling is irreversible
  end
end

# Step 3: Enforce NOT NULL
defmodule MyApp.Repo.Migrations.EnforcePostStatusNotNull do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      modify :status, :string, null: false, default: "draft"
    end
  end

  def down do
    alter table(:posts) do
      modify :status, :string, null: true, default: "draft"
    end
  end
end
```

**Add index concurrently** (safe for large tables):
```elixir
defmodule MyApp.Repo.Migrations.AddPostAuthorIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    create index(:posts, [:author_id], concurrently: true)
  end

  def down do
    drop index(:posts, [:author_id])
  end
end
```

---

### Phase 3: Verification

**Steps:**
1. Run the full test suite: `mix test`.
2. Verify migrations run in test environment: `MIX_ENV=test mix ecto.migrate`.
3. Review the migration with **quality/code-quality** and **security/security-essentials** if it handles sensitive data.
4. Use EXPLAIN ANALYZE for any data transformation queries to assess performance.

**HARD GATE — Test Suite Passes:**
```bash
mix test
MIX_ENV=test mix ecto.migrate
```

**If gate fails:** Fix tests or migration logic.

---

### Phase 4: Deployment

**Steps:**
1. **Deploy code first** (if using expand-contract, deploy code that handles both old and new schema).
2. **Run migration** — deploy the schema change.
3. **Run backfill** — if needed, run data transformation.
4. **Deploy cleanup code** — remove old column references, old table accesses.
5. **Run cleanup migration** — drop old columns/tables (optional, later deployment).

**HARD GATE — Rollback Ready:**
- [ ] Exact rollback command documented
- [ ] Rollback tested locally or on staging
- [ ] Database backup taken before production migration

---

## Output Style

When completing a migration, output MUST include:

```markdown
# Migration Report — [Migration Name]

## Plan
- Change: <description>
- Classification: safe / risky / dangerous
- Lock behavior: <assessment>
- Expand-contract: yes / no (steps: <list>)

## Implementation
- File: <migration file path>
- up: <brief description>
- down: <brief description>
- Idempotent cycle: migrate→rollback→migrate→rollback→migrate ✓

## Verification
- mix test: ✓ (<n> tests, 0 failures)
- MIX_ENV=test mix ecto.migrate: ✓

## Deployment Plan
- [ ] Code deployed (handles old + new schema)
- [ ] Migration applied
- [ ] Backfill run (if needed)
- [ ] Cleanup code deployed
- [ ] Rollback command documented: mix ecto.rollback
```

---

## Error Recovery

**Migration fails in production:**
1. Run `mix ecto.rollback` if the migration is reversible.
2. Diagnose from the error message: common causes are constraint violations, data type mismatches, and lock timeouts.
3. Fix locally, rerun the idempotent cycle, then redeploy.

**Rollback fails:**
1. Verify `down/0` reverses every operation in `up/0` in the correct order.
2. For `change/0` migrations, Ecto auto-generates the reverse; manual `up`/`down` must stay in sync.
3. If rollback is truly irreversible, document it and plan a forward-only fix migration.

**Lock timeout on large table:**
1. Add the column as nullable first, backfill, then enforce NOT NULL (expand-contract).
2. Always use `concurrently: true` and `@disable_ddl_transaction true` for index creation on large tables.
3. Schedule during low-traffic windows.

---

## Anti-Patterns to Avoid

- **Schema change + data backfill in same migration**
- **Dropping columns without removing code references first**
- **Adding NOT NULL without default**
- **Creating index without `concurrently` on large tables**
- **No `down/0` defined**
- **Skipping idempotent cycle test**

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|---------------|-----------|
| ecto-essentials | ecto-migration | None (standalone) |
