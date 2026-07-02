---
name: tdd
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates the full Elixir TDD cycle with hard gates: test MUST exist, be run, and FAIL for the correct reason (e.g. function not defined, not syntax error) before any implementation code — proposes minimal implementation and waits for user approval → verifies test PASSES → runs full suite (mix format, mix credo, mix dialyzer, mix test) all green → produces @doc documentation and self-reviewed PR. Operates in four phases: context/test design → implementation → iterate → finish. Use when practicing test-driven development, red-green-refactor, TDD workflow, writing tests before code, adding tests first, or building an Elixir feature where specs must gate implementation.
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
1. **Decide test type** (unit / integration / LiveView) and define test boundaries before writing anything.
2. **Write the minimal failing test** — see Example below.
3. **Run**: `mix test test/path/to/file_test.exs` — confirm it FAILS.

**HARD GATE — Test Feedback:**
- Test EXISTS and is RUN.
- FAILS for correct reason (e.g., `** (UndefinedFunctionError) function MyApp.Blog.list_posts/0 is undefined`).

**If gate fails:** If the failure is a syntax or config error instead of the expected missing-function error, fix the test itself (never the implementation) and re-run until it fails for the correct reason before proceeding.

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

**HARD GATE — Implementation Verification:**
- Explicit user approval obtained for the proposed implementation before writing any files.
- Target test PASSES.
- No new test failures introduced.

**If gate fails:** Diagnose the actual vs. expected result, revise the minimal implementation, and re-run the target test — do not proceed to Phase 3 until it is green.

### Phase 3: Iterate
1. **Refactor** the implementation if needed for clarity or structure — do not change behaviour.
2. **Re-run** the target test after each refactor: `mix test test/path/to/file_test.exs`.
3. **Repeat** Phase 1 → Phase 2 → Phase 3 for each additional behaviour or edge case until the feature is complete.
4. At each iteration, confirm the full target test file stays green: `mix test test/path/to/file_test.exs`.

### Phase 4: Finish
1. **Run full quality suite** in order:
   ```
   mix format --check-formatted
   mix credo --strict
   mix dialyzer
   mix test
   ```
2. **All four commands must be green.** If any fail:
   - `mix format`: run `mix format` then re-check, and re-run the remaining quality tools (`mix credo`, `mix dialyzer`, `mix test`) in case the formatting changes introduced any new issues.
   - `mix credo`: fix each flagged issue; do not suppress warnings without explicit user approval.
   - `mix dialyzer`: add or correct typespecs to resolve warnings.
   - `mix test`: diagnose regressions — do not proceed until all tests pass.

**HARD GATE — Quality Check:**
- All four mix commands exit with 0.
- No warnings suppressed without explicit user approval.

**If gate fails:** Apply the per-command fixes above (format → reformat and re-check; credo → fix each issue; dialyzer → correct typespecs; test → fix regressions), then re-run all four commands until every one is green.

3. **Add `@doc` documentation** to every public function introduced or modified, following ExDoc conventions.
4. **Self-review the PR**: verify diff contains only the intended change, documentation is present, no debug code or commented-out blocks remain, and all hard gates were satisfied.
5. **Produce the PR** with a description that references the failing test, the minimal implementation, and the quality suite result.

---

## Output Style

When completing a TDD cycle, output MUST include:

```markdown
# TDD Report — [Feature Name]

## Test Design
- Test type: unit / integration / LiveView
- Test file: <path>
- RED: <exact failure message>

## Implementation
- Proposal approved: yes
- File: <path and line range>
- GREEN: target test passes

## Quality Suite
- mix format --check-formatted: ✓
- mix credo --strict: ✓
- mix dialyzer: ✓
- mix test: ✓ (<n> tests, 0 failures)

## Docs & PR
- @doc on every new/changed public function: ✓
- Self-review complete: ✓

Verdict: PASS / FAIL — <one-line reason>
```

---

## Error Recovery

**Test fails for the wrong reason (syntax or config error):**
1. Fix the test itself, never the implementation.
2. Re-run until it fails with the expected `UndefinedFunctionError` (or equivalent behavioral failure).

**Implementation does not turn the test green:**
1. Compare actual vs. expected output; add no behavior beyond what the failing test requires.
2. Revise the minimal implementation and re-run the target test before touching anything else.

**Quality suite goes red in Phase 4:**
1. `mix format` → reformat, then re-run credo, dialyzer, and test.
2. `mix credo` → fix each issue; never suppress without explicit user approval.
3. `mix dialyzer` → add or correct typespecs.
4. `mix test` → diagnose regressions before producing the PR.

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|---------------|-----------|
| testing-essentials | tdd | None (standalone) |
