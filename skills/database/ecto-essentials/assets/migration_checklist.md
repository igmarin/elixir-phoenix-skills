# Ecto Migration Checklist

## Before Generating Migration
- [ ] Read current schema: `mix ecto.dump`
- [ ] Check table size and estimated lock duration for ALTER TABLE operations
- [ ] Plan rollback (exact `down/0` operations)
- [ ] Classify the change: safe / risky / dangerous

## Migration Code Conventions
- [ ] Uses `up/0` and `down/0` (not `change/0`) for complex migrations
- [ ] `@disable_ddl_transaction true` for concurrent index creation
- [ ] `concurrently: true` for indexes on large tables
- [ ] Composite primary keys use `primary_key: false` in table definition
- [ ] References use `type: :binary_id` for UUID foreign keys
- [ ] Timestamps added with `timestamps()` macro
- [ ] Migration name describes the action: `add_status_to_posts`, `create_comments_table`

## Testing Migrations
- [ ] `mix ecto.rollback` succeeds
- [ ] `mix ecto.migrate` succeeds
- [ ] Second `mix ecto.rollback` succeeds (idempotent)
- [ ] Second `mix ecto.migrate` succeeds (idempotent)
- [ ] `MIX_ENV=test mix ecto.migrate` succeeds
- [ ] `mix test` passes full suite

## Expand-Contract (for risky changes)
- [ ] Step 1: Add new column/table (nullable, no constraints)
- [ ] Step 2: Backfill data (separate migration or script)
- [ ] Step 3: Enforce constraint (NOT NULL, unique, etc.)
- [ ] Step 4: Deploy code that uses new schema
- [ ] Step 5: Remove old column/references (later deployment)
- [ ] Step 6: Drop old column/table (later deployment)

## Production Deployment
- [ ] Execute during low-traffic window for risky/dangerous changes
- [ ] Database backup confirmed before migration
- [ ] Rollback command documented and shared with team
- [ ] Code deployed BEFORE migration (handles old + new schema)
- [ ] Migration applied
- [ ] Backfill run (if needed)
- [ ] Cleanup code deployed
- [ ] Verify application health after migration

## Common Gotchas
- Avoid: schema change + data backfill in same migration
- Avoid: adding NOT NULL without default on existing tables
- Avoid: dropping columns without removing code references first
- Avoid: creating indexes without `concurrently` on large tables
- Avoid: renaming columns without a transition period
