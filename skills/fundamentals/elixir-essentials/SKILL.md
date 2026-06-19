---
name: elixir-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL Elixir code changes. Invoke before writing any .ex or .exs file.
  Covers pattern matching, pipe operator, with statements, error handling with tagged tuples,
  guards, list comprehensions, naming conventions, and the "let it crash" philosophy.
  Trigger words: elixir, pattern matching, pipe, with, error handling, tagged tuples, guards.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Elixir Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY `.ex` or `.exs` file.

## RULES — Follow these with no exceptions

1. **Use pattern matching over if/else** for control flow and data extraction
2. **Add `@impl true`** before every callback function (mount, handle_event, handle_info, etc.)
3. **Return `{:ok, result} | {:error, reason}` tuples** for fallible operations
4. **Use `with` for 2+ sequential fallible operations** instead of nested case
5. **Use the pipe operator** for 2+ chained transformations
6. **Never nest if/else statements** — use case, cond, or multi-clause functions
7. **Predicate functions end with `?`**, dangerous functions end with `!`
8. **Let it crash** — don't write defensive code for impossible states
9. **Use `@doc` and `@moduledoc`** for all public APIs
10. **Prefer immutability** — never mutate data in place

---

## Pattern Matching

Pattern matching is the primary control flow mechanism in Elixir. Prefer it over conditional statements.

### Prefer Pattern Matching Over if/else

❌ **Bad:**
```elixir
def process(result) do
  if result.status == :ok do
    result.data
  else
    nil
  end
end
```

✅ **Good:**
```elixir
def process(%{status: :ok, data: data}), do: data
def process(_), do: nil
```

### Use Case for Multiple Patterns

❌ **Bad:**
```elixir
def handle_response(response) do
  if response.status == 200 do
    {:ok, response.body}
  else if response.status == 404 do
    {:error, :not_found}
  else
    {:error, :unknown}
  end
end
```

✅ **Good:**
```elixir
def handle_response(%{status: 200, body: body}), do: {:ok, body}
def handle_response(%{status: 404}), do: {:error, :not_found}
def handle_response(_), do: {:error, :unknown}
```

## Pipe Operator

Use the pipe operator `|>` to chain function calls for improved readability.

### Basic Piping

❌ **Bad:**
```elixir
String.upcase(String.trim(user_input))
```

✅ **Good:**
```elixir
user_input
|> String.trim()
|> String.upcase()
```

### Pipe into Function Heads

❌ **Bad:**
```elixir
def process_user(user) do
  validated = validate_user(user)
  transformed = transform_user(validated)
  save_user(transformed)
end
```

✅ **Good:**
```elixir
def process_user(user) do
  user
  |> validate_user()
  |> transform_user()
  |> save_user()
end
```

## With Statement

Use `with` for sequential operations that can fail.

❌ **Bad (nested case):**
```elixir
def create_post(params) do
  case validate_params(params) do
    {:ok, valid_params} ->
      case create_changeset(valid_params) do
        {:ok, changeset} ->
          Repo.insert(changeset)
        error -> error
      end
    error -> error
  end
end
```

✅ **Good (with):**
```elixir
def create_post(params) do
  with {:ok, valid_params} <- validate_params(params),
       {:ok, changeset} <- create_changeset(valid_params),
       {:ok, post} <- Repo.insert(changeset) do
    {:ok, post}
  end
end
```

### With Statement — Inline Error Handling

Handle specific errors in the else block:

```elixir
def transfer_money(from_id, to_id, amount) do
  with {:ok, from_account} <- get_account(from_id),
       {:ok, to_account} <- get_account(to_id),
       :ok <- validate_balance(from_account, amount),
       {:ok, _} <- debit(from_account, amount),
       {:ok, _} <- credit(to_account, amount) do
    {:ok, :transfer_complete}
  else
    {:error, :insufficient_funds} ->
      {:error, "Not enough money in account"}

    {:error, :not_found} ->
      {:error, "Account not found"}

    error ->
      {:error, "Transfer failed: #{inspect(error)}"}
  end
end
```

## Guards

Use guards for simple type and value checks in function heads.

```elixir
def calculate(x) when is_integer(x) and x > 0 do
  x * 2
end

def calculate(_), do: {:error, :invalid_input}
```

## List Comprehensions

Use `for` comprehensions for complex transformations and filtering.

❌ **Bad (multiple passes):**
```elixir
list
|> Enum.map(&transform/1)
|> Enum.filter(&valid?/1)
|> Enum.map(&format/1)
```

✅ **Good (single pass):**
```elixir
for item <- list,
    transformed = transform(item),
    valid?(transformed) do
  format(transformed)
end
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Module names | `PascalCase` | `MyApp.Accounts.User` |
| Function names | `snake_case` | `create_user/1` |
| Variables | `snake_case` | `user_name` |
| Atoms | `:snake_case` | `:not_found` |
| Predicate functions | end with `?` | `valid?`, `empty?` |
| Dangerous functions | end with `!` | `save!`, `update!` |

## Tagged Tuples for Error Handling

The idiomatic way to handle success and failure in Elixir.

```elixir
def fetch_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

# Usage
case fetch_user(123) do
  {:ok, user} -> IO.puts("Found: #{user.name}")
  {:error, :not_found} -> IO.puts("User not found")
end
```

## Bang Functions

Functions ending with `!` raise errors instead of returning tuples.

```elixir
# Returns {:ok, user} or {:error, changeset}
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end

# Returns user or raises
def create_user!(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert!()
end
```

## Early Returns

Use pattern matching in function heads for early returns.

```elixir
def process_data(nil), do: {:error, :no_data}
def process_data([]), do: {:error, :empty_list}
def process_data(data) when is_list(data) do
  {:ok, Enum.map(data, &transform/1)}
end
```

## Avoid Defensive Programming

Don't check for things that can't happen. Let it crash.

❌ **Bad (defensive):**
```elixir
def get_username(user) do
  if user && user.name do
    user.name
  else
    "Unknown"
  end
end
```

✅ **Good (trust your types):**
```elixir
def get_username(%User{name: name}), do: name
```

If the user is nil or doesn't have a name, it's a bug that should crash and be fixed.

## Anonymous Functions

Use the capture operator `&` for concise anonymous functions.

❌ **Verbose:**
```elixir
Enum.map(list, fn x -> x * 2 end)
```

✅ **Concise:**
```elixir
Enum.map(list, &(&1 * 2))
```

✅ **Named function capture:**
```elixir
Enum.map(users, &User.format/1)
```

## Common Pitfalls

❌ **Don't** nest if/else — use pattern matching or case
❌ **Don't** forget `@impl true` on callbacks
❌ **Don't** use `String.to_atom/1` on user input (atom table exhaustion)
❌ **Don't** write defensive code for impossible states
❌ **Don't** chain more than 3 Enum operations without considering `for` comprehensions

✅ **Do** use pattern matching as primary control flow
✅ **Do** return tagged tuples for fallible operations
✅ **Do** pipe for 2+ transformations
✅ **Do** use `with` for sequential fallible operations
✅ **Do** let processes crash and rely on supervisors

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| None (always first) | elixir-essentials | testing-essentials |
| None (always first) | elixir-essentials | otp-essentials |
| None (always first) | elixir-essentials | typespec-dialyzer |
| None (always first) | elixir-essentials | code-quality |
