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

## Core Process

### 1. Define stable behavior

Identify the exact inputs and outputs of the logic being refactored. Keep public interfaces stable until callers are migrated. Prefer adapters, facades, or wrappers for transitional states.

Include in your output:
- **Stable behavior statement:** an explicit statement of what must not change (inputs/outputs, public interfaces).
- **Shim decision:** name any transitional adapter/facade/wrapper and its removal condition, or state why none is needed.

### 2. Add characterization tests

**Write this before touching any production file.** No refactoring step begins until this test exists and passes on the current (un-refactored) code. If the characterization test fails, do not continue — stop and fix the test or the behavior mismatch.

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

Good first moves include: extracting duplicated logic into a private helper, flattening a nested `case` into `with`, reducing a long pipe chain into named functions, or wrapping a context boundary. One boundary at a time — characterization tests first, verification after each step.

### 4. Execute extraction/refactor (One step at a time)

#### Extract Private Function (ABC complexity reduction)

**Before:**
```elixir
def calculate_trend_line(data) do
  # 50 lines of assignments, branches, conditions
end
```

**After:**
```elixir
def calculate_trend_line(data) do
  sums = calculate_regression_sums(data)
  slope = calculate_slope(sums)
  intercept = calculate_intercept(sums, slope)
  build_trend_points(data, slope, intercept)
end

defp calculate_regression_sums(data), do: # ...
defp calculate_slope(sums), do: # ...
defp calculate_intercept(sums, slope), do: # ...
defp build_trend_points(data, slope, intercept), do: # ...
```

#### Flatten Nested Case into With

**Before:**
```elixir
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
```

**After:**
```elixir
def process_order(order_id) do
  with {:ok, order} <- find_order(order_id),
       {:ok, valid_order} <- validate_order(order),
       {:ok, charge} <- charge_order(valid_order) do
    {:ok, charge}
  end
end
```

#### Reduce Pipe Chain into Named Functions

**Before:**
```elixir
def process_data(data) do
  data
  |> Enum.filter(&active?/1)
  |> Enum.map(&transform/1)
  |> Enum.sort()
  |> Enum.group_by(& &1.category)
  |> Enum.map(fn {cat, items} -> {cat, Enum.count(items)} end)
end
```

**After:**
```elixir
def process_data(data) do
  data
  |> filter_active()
  |> transform_all()
  |> group_by_category()
  |> count_per_category()
end

defp filter_active(data), do: Enum.filter(data, &active?/1)
defp transform_all(data), do: Enum.map(data, &transform/1)
defp group_by_category(data), do: Enum.group_by(data, & &1.category)
defp count_per_category(groups), do: Enum.map(groups, fn {cat, items} -> {cat, Enum.count(items)} end)
```

#### Extract Context Boundary

**Before:**
```elixir
defmodule MyApp.Accounts do
  def send_welcome_email(user) do
    email = MyApp.Mailers.UserEmail.welcome(user)
    MyApp.Mailer.deliver(email)
  end
end
```

**After:**
```elixir
defmodule MyApp.Accounts do
  alias MyApp.Mail

  def register_user(attrs) do
    with {:ok, user} <- create_user(attrs) do
      Mail.send_welcome(user)
      {:ok, user}
    end
  end
end
```

### 5. Verification Protocol

Run verification after every refactoring step:

1. Run the relevant test file: `mix test test/path/to/file_test.exs`
2. Read the output — check exit code, count failures
3. If tests fail: STOP, undo the step, investigate
4. If tests pass: proceed to next step
5. At the end, run full suite: `mix test`
6. Only claim completion with evidence from the last test run

**Evidence labelling rules:** Label actual run output as **Observed output** only. Never use labels such as "Expected output", "Required output", or "Planned output" as substitutes for actual observed run output. If you have not run the tests, you have no observed output to report.

Report test run output at EACH step — not only at the end. At least two separate **Observed output** entries at different sequence points are required.

## Common Pitfalls

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| Refactoring without characterization tests | Capture current behavior with tests first |
| Changing behavior during refactoring | Only change structure, not output |
| Multiple logical changes in one step | One extraction per commit |
| Mixing refactoring with new features | Complete refactor first, add feature in separate step |
| Skipping full suite regression check | `mix test` must pass at end |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| code-review | refactor-code | code-quality |

**Companion skills:**
- `code-quality` — Credo complexity detection and quality gate
- `testing-essentials` — fixture and test setup patterns
- `apply-phoenix-liveview-conventions` — LiveView-specific refactoring