---
name: ecto-essentials
type: atomic
description: Use for Ecto schemas, queries, changesets, associations, preloads, transactions, and persistence boundaries in an existing Elixir project.
metadata:
  user-invocable: "true"
---

# Ecto Essentials

Follow the repository's Ecto and database conventions. Keep business rules in the context or pure domain modules; keep `Repo` calls at the persistence edge.

## Schemas and changesets

- Model persisted data in schemas and validate external input with changesets.
- Use `cast/3` with an explicit field allowlist for external maps. Use `change/2` for trusted internal updates.
- Attach database constraints to changesets with `unique_constraint/3`, `foreign_key_constraint/3`, or the matching constraint helper so expected database errors return changeset errors.
- Keep association ownership and delete behavior explicit. Use `cast_assoc/3` only when nested input is part of the public operation.

## Queries and associations

- Compose `Ecto.Query` fragments with named bindings and parameterized values. Never interpolate user input into SQL.
- Keep reusable filters and ordering in query functions; keep policy and orchestration in the context.
- Preload what the caller needs. For lists, inspect query counts and prefer joins or batched preloads over per-row `Repo.get/2` calls.
- Use `Repo.one/1`, `Repo.all/1`, and bang variants according to the caller's expected absence and error contract.

## Writes and transactions

- Return `{:ok, value}` / `{:error, changeset_or_reason}` from expected failures.
- Use `Ecto.Multi` when a transaction has multiple named steps or its failure step matters to the caller. Use a normal transaction for a small atomic block.
- Do not put network calls or other irreversible side effects inside a database transaction.
- For upserts, state the conflict target and verify the database constraint matches it.

## Verification

Add or update tests for the changed persistence behavior. Run the focused test, then the project checks that cover Ecto and migrations. Use `ecto-changeset-patterns`, `ecto-nested-associations`, or `ecto-migration` only when that narrower behavior is central.
