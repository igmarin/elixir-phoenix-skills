---
name: tdd
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates the full Elixir TDD cycle with hard gates: test MUST exist, be run, and FAIL for the correct reason (e.g. function not defined, not syntax error) before any implementation code — proposes minimal implementation and waits for user approval → verifies test PASSES → runs full suite (mix format, mix credo, mix dialyzer, mix test) all green → produces @doc documentation and self-reviewed PR. Operates in four phases: context/test design → implementation → iterate → finish. Use when practicing test-driven development, red-green-refactor, TDD workflow, writing tests before code, adding tests first, or building an Elixir feature where specs must gate implementation.
---

# TDD Persona

Orchestrates the full Elixir TDD cycle. Write the test first, watch it fail for the right reason, implement the minimal fix, then verify quality.

## Agent Phases

### Phase 1: Context & Test Design
1. **Decide test type** (unit / integration / LiveView) and define test boundaries before writing anything.
2. **Write the minimal failing test** — see Example below.
3. **Run**: `mix test test/path/to/file_test.exs` — confirm it FAILS.

**HARD GATE — Test Feedback**
- Test EXISTS and is RUN.
- FAILS for correct reason (e.g., `** (UndefinedFunctionError) function MyApp.Blog.list_posts/0 is undefined`).
- If FAIL is incorrect (syntax error, config issue), fix the test before proceeding.

#### Example: Minimal Failing Test
```elixir
# test/my_app/blog_test.exs
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.Blog

  describe "list_posts/0" do
    test "returns all published posts" do
      post = post_fixture(published: true)
      assert Blog.list_posts() == [post]
    end
  end
end
```

Expected failure output:
```
** (UndefinedFunctionError) function MyApp.Blog.list_posts/0 is undefined or private
```

### Phase 2: Implementation
1. **Proposal Checkpoint**: Propose the minimal implementation that will make the failing test pass — no more, no less. Present the proposed code to the user and **wait for explicit approval** before writing any files.
2. **On approval**: Write the implementation.
3. **Run**: `mix test test/path/to/file_test.exs` — confirm the target test now PASSES.

**HARD GATE — Implementation Verification**
- Explicit user approval obtained for the proposed implementation before writing any files.
- Target test PASSES.
- No new test failures introduced.
- If test still fails, diagnose and revise — do not proceed to Phase 3 until green.

### Phase 3: Iterate
1. **Refactor** the implementation if needed for clarity or structure — do not change behaviour.
2. **Re-run** the target test after each refactor: `mix test test/path/to/file_test.exs`.
3. **Repeat** Phase 1 → Phase 2 → Phase 3 for each additional behaviour or edge case until the feature is complete.
4. At each iteration, confirm the full target test file stays green: `mix test test/path/to/file_test.exs`.

### Phase 4: Finish

#### 4a. Quality Suite
Run all four commands in order — **all must exit with 0**:
```
mix format --check-formatted
mix credo --strict
mix dialyzer
mix test
```

#### 4b. Remediation (if any command fails)
| Command | Action |
|---|---|
| `mix format` | Run `mix format`, re-check, then re-run `mix credo`, `mix dialyzer`, and `mix test` in case formatting changes introduced new issues. |
| `mix credo` | Fix each flagged issue; do not suppress warnings without explicit user approval. |
| `mix dialyzer` | Add or correct typespecs to resolve warnings. |
| `mix test` | Diagnose regressions — do not proceed until all tests pass. |

**HARD GATE — Quality Check**
- All four mix commands exit with 0.
- No warnings suppressed without explicit user approval.

#### 4c. Documentation & PR
1. **Add `@doc` documentation** to every public function introduced or modified, following ExDoc conventions.
2. **Self-review the PR**: verify diff contains only the intended change, documentation is present, no debug code or commented-out blocks remain, and all hard gates were satisfied.
3. **Produce the PR** with a description that references the failing test, the minimal implementation, and the quality suite result.


## Integration

| Predecessor | This Persona | Successor |
|-------------|---------------|-----------|
| `testing-essentials` (skill dependency — provides base test conventions and helpers) | tdd | None (standalone) |
