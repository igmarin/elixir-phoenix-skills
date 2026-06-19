---
name: tdd
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates the full Elixir TDD cycle with hard gates: test MUST exist, be run, and FAIL for the correct reason (e.g. function not defined, not syntax error) before any implementation code — propose minimal implementation and wait for user approval → verify test PASSES → run full suite with mix format, mix credo, mix dialyzer, mix test all green → produce @doc documentation and self-reviewed PR; phases context/test design→implementation→iterate→finish. Use when practicing test-driven development, red-green-refactor, TDD workflow, writing tests before code, adding tests first, or building an Elixir feature where specs must gate implementation.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when practicing test-driven development or building Elixir features where specs must gate implementation"
  phases: "Phase 1: Context & Test Design, Phase 2: Implementation, Phase 3: Iterate, Phase 4: Finish"
  hard_gates: "Test Feedback, Proposal Checkpoint, Implementation Verification, Quality Check"
  dependencies:
    - source: self
      skills: [testing-essentials, code-quality]
  keywords: elixir, phoenix, tdd, agent, feature, implementation, testing, orchestration
---
# TDD Persona

Orchestrates the full Elixir TDD cycle. Write the test first, watch it fail for the right reason, implement the minimal fix, then verify quality.

## Agent Phases

### Phase 1: Context & Test Design
1. **testing/testing-essentials**: Decide test type (unit / integration / LiveView) and test boundaries.
2. **Write the minimal failing test** — see Example below.
3. **Run**: `mix test test/path/to/file_test.exs` — confirm it FAILS.

**HARD GATE — Test Verification**
- Test EXISTS and is RUN.
- FAILS for correct reason (e.g., `** (UndefinedFunctionError) function MyApp.Blog.list_posts/0 is undefined`).
- If FAIL is incorrect (syntax, config), fix the test.

### Phase 2: Implementation
1. **Proposal Checkpoint**: Propose implementation (e.g., "Add `list_posts/0` to `MyApp.Blog` context").
2. **User Approval**: Wait for explicit confirmation.
3. **Minimal Implement**: Smallest change to pass test.
4. **Verify PASS**: `mix test test/path/to/file_test.exs`.

*If test does not pass, fix minimal changes and re-verify.*

### Phase 3: Iterate (Optional)
Return to Phase 1 for next behavior or proceed to Phase 4.

### Phase 4: Finish
1. **Quality Check**: `mix format --check-formatted && mix credo && mix dialyzer && mix test`.
2. **Document public API**: Add `@doc` and `@moduledoc` to all public functions.
3. **quality/code-quality**: Self-review PR diff.
4. **Open PR**: Feature complete.

## Concrete Example

Abbreviated walkthrough for adding a `list_posts/0` function to a Blog context.

**Step 1 — Write the failing test** (`test/my_app/blog_test.exs`):
```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.Blog

  describe "list_posts/0" do
    test "returns all posts" do
      post = post_fixture()
      assert Blog.list_posts() == [post]
    end
  end

  defp post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{title: "Test", body: "Body"})
      |> Blog.create_post()

    post
  end
end
```
Run: `mix test test/my_app/blog_test.exs`
Expected failure: `** (UndefinedFunctionError) function MyApp.Blog.list_posts/0 is undefined`

**Step 2 — Propose & confirm**
> Proposal: Add `def list_posts, do: Repo.all(Post)` to `lib/my_app/blog.ex`. Proceed?

**Step 3 — Minimal implementation** (`lib/my_app/blog.ex`):
```elixir
@doc """
Returns the list of posts.
"""
def list_posts do
  Repo.all(Post)
end
```
Run: `mix test test/my_app/blog_test.exs` → `1 test, 0 failures`

**Step 4 — Quality check**:
```bash
mix format --check-formatted && mix credo && mix dialyzer && mix test
```
All green → add @doc → self-review → open PR.

---

## Output Style

When completing a TDD cycle, produce a report with:

- **RED**: test file path and line, exact failure message, confirmation the failure is for the correct reason.
- **Proposal**: one-line implementation summary and explicit user approval confirmation.
- **GREEN**: implementation file path and line, test pass confirmation.
- **Iterate**: number of additional RED→GREEN cycles and a summary of each.
- **Quality Gate**: `mix format`, `mix credo`, `mix dialyzer`, `mix test` results.

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|--------------|----------|
| elixir-skill-router | tdd | code-quality |
| None (standalone) | tdd | quality |
| None (standalone) | tdd | PR submission |

**Use `testing-essentials` alone** if you only need to decide which test to write next.

**Use `tdd` for the full cycle** when building a feature from scratch.

---

## Error Recovery

**Test fails for the wrong reason (syntax/config error):**
1. Identify error class — `SyntaxError`, `File.Error` indicate test problems, not missing features.
2. Fix the test to correctly target the missing behavior and re-run until the failure class is correct (e.g., `UndefinedFunctionError`).

**Implementation makes test pass but breaks other tests:**
1. Run `mix test` to identify regressions.
2. Revise implementation to satisfy both the new test and existing tests.
3. If impossible, the feature conflicts with existing behavior — discuss with user before proceeding.

**Quality gate fails (credo/dialyzer):**
1. Run `mix credo --strict` to see all violations; fix them.
2. For dialyzer warnings, assess whether they expose a real type error.
3. Run `mix format` to auto-fix formatting issues.
