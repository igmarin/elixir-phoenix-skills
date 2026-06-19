---
name: property-based-testing
type: atomic
license: MIT
description: >
  Use when writing tests that need to cover many input combinations. Invoke before writing complex
  test scenarios with edge cases. Covers StreamData, ExUnitProperties, generators, shrinking,
  and property-based testing patterns.
  Trigger words: property-based testing, StreamData, ExUnitProperties, generators, fuzzing, shrinking.
metadata:
  version: 1.0.0
---

# Property-Based Testing

Property-based testing generates hundreds of test cases automatically, finding edge cases you'd never think to write.

## RULES — Follow these with no exceptions

1. **Define properties, not examples** — state what should always be true, not specific inputs/outputs
2. **Use `ExUnitProperties` for generators** — the standard library for property-based testing in Elixir
3. **Start with simple generators** — `integer()`, `string()`, `list_of()` before custom generators
4. **Test invariants, not specific values** — "output length equals input length" not "output is [1, 2, 3]"
5. **Use `check all` for multiple properties** — test several invariants in one property
6. **Leverage shrinking** — let StreamData find minimal failing cases
7. **Combine with example-based tests** — property-based tests complement, not replace, unit tests

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

### Built-in Generators

```elixir
# Integers
integer()              # Any integer
integer(0..100)        # Integer in range
positive_integer()     # Positive integers

# Strings
string(:ascii)         # ASCII strings
string(:alphanumeric)  # Alphanumeric strings
binary()               # Binary data

# Collections
list_of(integer())           # List of integers
list_of(integer(), min_length: 1)  # Non-empty list
map_of(string(), integer())    # Map with string keys

# Booleans and nil
boolean()
constant(nil)
one_of([constant(:a), constant(:b), constant(:c)])
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

      # Check that each element is <= the next
      sorted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert a <= b
      end)
    end
  end

  property "sorted list has same length as original" do
    check all list <- list_of(integer()) do
      assert length(Enum.sort(list)) == length(list)
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

## Combining Properties

```elixir
property "JSON encoding and decoding is idempotent" do
  check all data <- map_of(string(:alphanumeric), one_of([integer(), string(:ascii), boolean()])) do
    encoded = Jason.encode!(data)
    decoded = Jason.decode!(encoded)

    # Keys are always strings after decode
    assert Map.keys(decoded) == Map.keys(data)

    # Values match (with type coercion for integers)
    for {key, value} <- data do
      case value do
        v when is_integer(v) -> assert decoded[key] == v
        v when is_binary(v) -> assert decoded[key] == v
        v when is_boolean(v) -> assert decoded[key] == v
      end
    end
  end
end
```

---

## Shrinking

StreamData automatically shrinks failing cases to find minimal examples:

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

## When to Use Property-Based Testing

✅ **Good candidates:**
- Data transformations (encoding, parsing, formatting)
- Mathematical operations
- Sorting and filtering algorithms
- State machines
- Serialization/deserialization

❌ **Not ideal for:**
- Database operations (use fixtures)
- External API calls (use mocks)
- UI interactions (use LiveView tests)
- Simple CRUD operations

---

## Common Pitfalls

❌ **Don't** write example-based tests as property tests
❌ **Don't** use overly complex generators — start simple
❌ **Don't** ignore shrinking — it finds minimal failing cases
❌ **Don't** replace all unit tests with property tests
❌ **Don't** forget to test invariants, not specific values

✅ **Do** define properties (invariants), not examples
✅ **Do** use built-in generators first
✅ **Do** leverage shrinking for debugging
✅ **Do** combine with example-based tests
✅ **Do** test transformations and algorithms

## Integration

| Skill | When to chain |
|-------|---------------|
| **testing-essentials** | For general testing patterns |
| **benchee-profiling** | For performance testing |
