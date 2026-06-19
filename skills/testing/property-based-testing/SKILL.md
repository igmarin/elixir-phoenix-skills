---
name: property-based-testing
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when writing tests that need to cover many input combinations or complex edge cases. Generates
  custom StreamData generators, writes ExUnitProperties tests, configures shrinking strategies, and
  creates property-based test patterns for data transformations, algorithms, and state machines.
  Trigger words: property-based testing, StreamData, ExUnitProperties, generators, fuzzing, shrinking.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Property-Based Testing

## RULES — Follow these with no exceptions

1. **Define properties, not examples** — state what should always be true, not specific inputs/outputs
2. **Use `ExUnitProperties` for generators** — the standard library for property-based testing in Elixir
3. **Start with simple generators** — `integer()`, `string()`, `list_of()` before custom generators
4. **Test invariants, not specific values** — "output length equals input length" not "output is [1, 2, 3]"
5. **Leverage shrinking** — let StreamData find minimal failing cases

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:stream_data, "~> 1.0", only: :test}
  ]
end
```

```elixir
# test/test_helper.exs
ExUnit.start()
```

---

## Basic Property Test

```elixir
defmodule MyApp.StringUtilsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "reversing a string twice returns the original" do
    check all string <- string(:ascii) do
      assert string |> String.reverse() |> String.reverse() == string
    end
  end

  property "length of reversed string equals original length" do
    check all string <- string(:ascii) do
      assert String.length(String.reverse(string)) == String.length(string)
    end
  end
end
```

---

## Generators

### Less Obvious Built-ins

```elixir
# Combine multiple generators with one_of
one_of([constant(:a), constant(:b), constant(:c)])
one_of([integer(), string(:ascii), boolean()])

# Compose generators with gen all
gen all x <- integer(0..100),
        y <- integer(0..100),
        x != y do
  {x, y}
end

# Non-empty collections
list_of(integer(), min_length: 1)
map_of(string(:alphanumeric), integer())
```

### Custom Generators

```elixir
# Generate a valid email
def email_generator do
  gen all name <- string(:alphanumeric, min_length: 3),
          domain <- string(:alphanumeric, min_length: 3) do
    "#{name}@#{domain}.com"
  end
end

# Generate a user struct
def user_generator do
  gen all email <- email_generator(),
          age <- integer(18..120) do
    %User{email: email, age: age}
  end
end

# Use in tests
property "users have valid emails" do
  check all user <- user_generator() do
    assert user.email =~ ~r/@.*\.com$/
    assert user.age >= 18 and user.age <= 120
  end
end
```

---

## Testing Invariants

```elixir
defmodule MyApp.SortingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "sorted list is ordered" do
    check all list <- list_of(integer()) do
      sorted = Enum.sort(list)

      sorted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] -> assert a <= b end)
    end
  end

  property "sorted list contains same elements" do
    check all list <- list_of(integer()) do
      assert Enum.sort(list) |> Enum.frequencies() == Enum.frequencies(list)
    end
  end
end
```

---

## Shrinking

```elixir
property "no list contains its own length as element" do
  check all list <- list_of(integer()) do
    # This will fail and shrink to a minimal example
    refute list |> Enum.member?(length(list))
  end
end

# StreamData will find and report:
# Failed with generated values: [0]
# (shrunk from something like [1, 5, 0, 3, 2])
```

---

## Workflow: Write → Run → Interpret → Refine

1. **Write property** — define an invariant using `check all` with appropriate generators
2. **Run test** — `mix test test/my_test.exs`
3. **Interpret shrinking output** — on failure, StreamData reports both the original failing input and the shrunk minimal example:
   ```
   ** (ExUnit.AssertionError)
   Failed with generated values (after 3 successful runs):

       * Clause:    list <- list_of(integer())
         Generated: [0]
         (shrunk from [42, -7, 0, 15])
   ```
4. **Refine generator or property** — if the shrunk case reveals a generator producing invalid inputs, add constraints (e.g. `min_length: 1`, `integer(1..100)`); if it reveals a real bug, fix the implementation
5. **Re-run** — confirm the fix holds across new generated cases

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| testing-essentials | property-based-testing | None (standalone) |
