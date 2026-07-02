---
name: refactor-code
type: atomic
license: MIT
tags: [atomic, quality]
description: >
  Use when refactoring Elixir code to change structure without changing behavior.
  Must write characterization tests and verify they pass on the current code BEFORE
  touching any production files, identify inputs/outputs keeping public interfaces
  stable, run verification after every step and the full suite at the end, and
  include a Stable behavior statement and Verification evidence showing actual
  command output under the Observed output label.
  Trigger words: refactor, restructure, extract function, extract module, reduce
  duplication, split module, flatten with, reduce pipe chain, extract context.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Refactor Code

Use this skill when the task is to change structure without changing intended behavior.

**Core principle:** Small, reversible steps over large rewrites. Separate design improvement from behavior change.

## Quick Reference

| Step | Action | Verification |
|------|--------|------|
| 1 | Define stable behavior | Written statement of what must not change |
| 2 | Add characterization tests | `mix test` passes on current code |
| 3 | Choose smallest safe slice | One boundary at a time |
| 4 | Rename, move, or extract | `mix test` still passes |
| 5 | Remove compatibility shims | `mix test` still passes, new path proven |

## HARD-GATE

```text
NO REFACTORING WITHOUT CHARACTERIZATION TESTS FIRST.
NEVER mix behavior changes with structural refactors in the same step —
  if behavior changes are also needed, complete the structural refactor first,
  then apply behavior changes in a separate step with its own test.
ONE boundary per refactoring step — never extract two abstractions in the same step.
If a public interface changes, document the compatibility shim and its removal condition.
NEVER fabricate test output — label only actual run output as Observed output.
```

These constraints are authoritative. The process steps below implement them; do not re-derive or relax them.

## RULES — Follow these with no exceptions

1. **Write characterization tests first** — they must pass on the current, un-refactored code before you touch any production file.
2. **Never mix behavior changes with structural refactors** in the same step — finish the structural refactor, then change behavior in a separate step with its own test.
3. **Refactor one boundary per step** — never extract two abstractions in the same step.
4. **Keep public interfaces stable** until callers are migrated — document any compatibility shim/facade and its removal condition, or state why none is needed.
5. **Verify after every step** — run the relevant test file after each change and the full `mix test` suite at the end.
6. **Stop and undo on failure** — if a test fails after a step, revert that step and investigate; fix the code, never the test.
7. **Label only actual run output as `Observed output`** — never fabricate output or use "Expected/Planned output" as a substitute, and provide at least two Observed output entries at different sequence points.
8. **Include an explicit Stable behavior statement** describing exactly which inputs/outputs and public interfaces must not change.

## Core Process

### 1. Define stable behavior

Identify the exact inputs and outputs of the logic being refactored. Keep public interfaces stable until callers are migrated. Prefer adapters, facades, or wrappers for transitional states.

Include in your output:
- **Stable behavior statement:** an explicit statement of what must not change (inputs/outputs, public interfaces).
- **Shim decision:** name any transitional adapter/facade/wrapper and its removal condition, or state why none is needed.

### 2. Add characterization tests

Write this test and confirm it passes on the **current** (un-refactored) code before touching any production file. If it fails, stop and fix the test or the behavior mismatch before continuing.

```elixir
# test/my_app/accounts_test.exs
defmodule MyApp.AccountsRefactorTest do
  use MyApp.DataCase

  describe "current behavior — register_user/1" do
    test "creates user with valid attrs" do
      assert {:ok, %User{} = user} = Accounts.register_user(%{email: "a@b.com", name: "Alice"})
      assert user.email == "a@b.com"
      assert user.name == "Alice"
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = Accounts.register_user(%{email: ""})
    end
  end
end
```

Run it: `mix test test/my_app/accounts_test.exs` — it must pass on the **current** code.

### 3. Choose the smallest safe slice

Good first moves include: extracting duplicated logic into a private helper, flattening a nested `case` into `with`, reducing a long pipe chain into named functions, or wrapping a context boundary. One boundary at a time.

### 4. Execute extraction/refactor (One step at a time)

Apply structural changes only — do not add, remove, or alter behavior in this step. The patterns below illustrate the general approach; adapt them to the specific codebase.

**Example — Flatten Nested Case into With:**

```elixir
# Before
def process_order(order_id) do
  case find_order(order_id) do
    {:ok, order} ->
      case validate_order(order) do
        {:ok, valid_order} ->
          case charge_order(valid_order) do
            {:ok, charge} -> {:ok, charge}
            error -> error
          end
        error -> error
      end
    error -> error
  end
end

# After
def process_order(order_id) do
  with {:ok, order} <- find_order(order_id),
       {:ok, valid_order} <- validate_order(order),
       {:ok, charge} <- charge_order(valid_order) do
    {:ok, charge}
  end
end
```

Other common structural moves (apply the same characterization-test-first discipline to each):
- **Extract private function** — decompose a long function body into named `defp` helpers, keeping the public signature identical.
- **Reduce pipe chain** — replace anonymous inline transformations with named private functions that each do one thing.
- **Extract context boundary** — move cross-context calls behind a module alias or thin wrapper, preserving the calling interface exactly.

### 5. Verification Protocol

Run verification after every refactoring step:

1. Run the relevant test file: `mix test test/path/to/file_test.exs`
2. Read the output — check exit code, count failures
3. If tests fail: STOP, undo the step, investigate
4. If tests pass: proceed to next step
5. At the end, run full suite: `mix test`
6. Only claim completion with evidence from the last test run

**Evidence labelling rules (authoritative):** Label actual run output as **Observed output** only. Never use labels such as "Expected output", "Required output", or "Planned output" as substitutes for actual observed run output. If you have not run the tests, you have no observed output to report. Report test run output at EACH step — not only at the end. At least two separate **Observed output** entries at different sequence points are required.

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Start refactoring before any tests exist | Write characterization tests that pass on the current code first |
| Change behavior and structure in the same step | Complete the structural refactor, then change behavior in a separate step |
| Extract two abstractions at once | Refactor one boundary per step |
| Change a public interface with no migration path | Keep the interface stable behind a shim and document its removal condition |
| Edit the test until it passes after a refactor | Fix the production code — a failing characterization test means behavior changed |
| Run the suite only at the very end | Verify after every step and run the full `mix test` at the end |
| Label planned or expected results as evidence | Report only actual runs as `Observed output` (≥2 entries) |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| code-quality | refactor-code | code-review |
| testing-essentials | refactor-code | code-quality |

**Companion skills:**
- `code-quality` — identifies the duplication and complexity that motivates a refactor
- `testing-essentials` — provides the test harness the characterization tests build on
- `code-review` — reviews the structural change once behavior is proven unchanged
