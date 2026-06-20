# Quality Task

## Problem

An Elixir/Phoenix team needs help with a task in this area:

Complete code quality loop for Elixir projects with hard gates: enforce formatting and linter compliance (mix format, mix credo must pass) → refactor only after characterization tests PASS on current code, verify behavior preserved after each extraction → generate @doc for all public APIs → NEVER open PR before formatter, credo, dialyzer, full test suite, and @doc coverage all pass; phases conventions review→refactoring→documentation.

The team has asked for a concise implementation artifact that a reviewer can inspect without needing to observe the agent's process.

## Output

Create `answer.md` with:

- a short plan for the work
- the concrete Elixir/Phoenix-oriented artifact or recommendation
- the verification steps or quality gates that should be run
- any assumptions that affect the result
