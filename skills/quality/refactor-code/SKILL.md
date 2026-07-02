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
  duplication, split module, flatten with, reduce pipe chain, extract bounded context.
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

## RULES — Follow these with no exceptions

1. **Write characterization tests before touching any production file** — they must pass on the current, un-refactored code first
2. **Never mix behavior changes with structural refactors in the same step** — finish the structural change, then apply behavior changes separately with their own test
3. **Refactor one boundary per step** — never extract two abstractions at once
4. **Keep public interfaces stable** — document any compatibility shim and its removal condition
5. **Run `mix test` after every step** — if it fails, STOP, undo the step, and investigate
6. **Run the full `mix test` suite at the end** before declaring the refactor complete
7. **Label only actual run output as `Observed output`** — never fabricate output or substitute "Expected"/"Planned" output
8. **Report at least two `Observed output` entries** at different sequence points

## Core Process

### 1. Define stable behavior

Identify the exact inputs and outputs of the logic being refactored. Keep public interfaces stable until callers are migrated. Prefer adapters, facades, or wrappers for transitional states.

Include in your output:
- **Stable behavior statement:** an explicit statement of what must not change (inputs/outputs, public interfaces).
- **Shim decision:** name any transitional adapter/facade/wrapper and its removal condition, or state why none is needed.

### 2. Add characterization tests

**Write this before touching any production file.** No refactoring step begins until this test exists and passes on the current (un-refactored) code. If the characterization test fails, stop and fix the test or the behavior mismatch before continuing.

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

Run it: `mix test test/my_app/accounts_test.exs` — it must pass on the **current** code before any production file is changed.

### 3. Choose the smallest safe slice

Good first moves: extract duplicated logic into a private helper, flatten a nested `case` into `with`, reduce a long pipe chain into named functions, or wrap a context boundary. One boundary at a time.

### 4. Execute extraction/refactor (one step at a time)

Apply the appropriate pattern below. Each shows a representative before/after; adapt to your context.

#### Extract Private Function (ABC complexity reduction)

```elixir
# Before: one large public function
def calculate_trend_line(data) do
  # 50 lines of assignments, branches, conditions
end

# After: delegate to named private helpers
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

```elixir
# Before
def process_order(order_id) do
  case find_order(order_id) do
    {:ok, order} ->
      case validate_order(order) do
        {:ok, valid_order} -> charge_order(valid_order)
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

#### Reduce Pipe Chain into Named Functions

```elixir
# Before
def process_data(data) do
  data
  |> Enum.filter(&active?/1)
  |> Enum.map(&transform/1)
  |> Enum.group_by(& &1.category)
  |> Enum.map(fn {cat, items} -> {cat, Enum.count(items)} end)
end

# After
def process_data(data) do
  data |> filter_active() |> transform_all() |> group_by_category() |> count_per_category()
end

defp filter_active(data), do: Enum.filter(data, &active?/1)
defp transform_all(data), do: Enum.map(data, &transform/1)
defp group_by_category(data), do: Enum.group_by(data, & &1.category)
defp count_per_category(groups), do: Enum.map(groups, fn {cat, items} -> {cat, Enum.count(items)} end)
```

#### Extract Context Module Boundary

```elixir
# Before: Accounts calls mailer directly
defmodule MyApp.Accounts do
  def send_welcome_email(user) do
    MyApp.Mailer.deliver(MyApp.Mailers.UserEmail.welcome(user))
  end
end

# After: delegate through a Mail context
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

This is the single authoritative source for all verification rules.

- Run `mix test test/path/to/file_test.exs` **after every refactoring step** and check exit code and failure count.
- If tests fail: **STOP, undo the step, investigate.**
- At the end, run the full suite: `mix test`.
- **Evidence labelling:** Label actual run output as **Observed output** only. Never use labels such as "Expected output", "Required output", or "Planned output" as substitutes for actual observed run output.
- Report test run output at EACH step — not only at the end. At least two separate **Observed output** entries at different sequence points are required.

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Start refactoring before writing characterization tests | Write and pass characterization tests on the current code first |
| Change behavior and structure in the same step | Do the structural refactor first, behavior change separately |
| Extract two abstractions in one step | Refactor one boundary per step |
| Break the public interface silently | Keep interfaces stable; document the shim and its removal |
| Test only at the end of the refactor | Run `mix test` after every step; stop and undo on failure |
| Paste fabricated or "expected" test output | Label only actual run output as `Observed output` |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| code-review | refactor-code | code-quality |

**Companion skills:**
- `code-quality` — Credo complexity detection and quality gate
- `testing-essentials` — fixture and test setup patterns
- `apply-phoenix-liveview-conventions` — LiveView-specific refactoring
