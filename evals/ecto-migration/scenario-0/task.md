# Ecto Migration Task

## Problem

An Elixir/Phoenix team needs help with a task in this area:

Orchestrates safe database migrations with hard gates: plan migration assessing lock behavior, rollback strategy, and performance impact → write and test migration with migrate/rollback/re-migrate idempotent cycle → never combine schema change and data backfill in one migration → use expand-contract for column changes (add nullable→backfill→enforce NOT NULL in separate migrations) → verify full test suite passes; phases planning→implementation→verification→deployment.

The team has asked for a concise implementation artifact that a reviewer can inspect without needing to observe the agent's process.

## Output

Create `answer.md` with:

- a short plan for the work
- the concrete Elixir/Phoenix-oriented artifact or recommendation
- the verification steps or quality gates that should be run
- any assumptions that affect the result
