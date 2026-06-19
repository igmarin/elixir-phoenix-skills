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
2. **Use `@impl true`** before every callback function (mount, handle_event, handle_info, etc.)
3. **Produce `{:ok, result} | {:error, reason}` tuples** for fallible operations
4. **Use `with` for 2+ sequential fallible operations** instead of nested case
5. **Use the pipe operator** for 2+ chained transformations
6. **Never nest if/else statements** — use case, cond, or multi-clause functions
7. **Use `?` suffix for predicate functions**, `!` suffix for dangerous functions
8. **Never write defensive code for impossible states** — let it crash
9. **Use `@doc` and `@moduledoc`** for all public APIs
10. **Prefer immutability** — never mutate data in place
11. **Don't** use `String.to_atom/1` on user input (atom table exhaustion)
12. **Prefer `for` comprehensions** before chaining 3+ Enum operations

---

## Pattern Matching

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

```elixir
def process_user(user) do
  user
  |> validate_user()
  |> transform_user()
  |> save_user()
end
```

## With Statement

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

```elixir
def calculate(x) when is_integer(x) and x > 0 do
  x * 2
end

def calculate(_), do: {:error, :invalid_input}
```

## List Comprehensions

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
|---------|-----------|--------|
| Module names | `PascalCase` | `MyApp.Accounts.User` |
| Function names | `snake_case` | `create_user/1` |
| Variables | `snake_case` | `user_name` |
| Atoms | `:snake_case` | `:not_found` |
| Predicate functions | end with `?` | `valid?`, `empty?` |
| Dangerous functions | end with `!` | `save!`, `update!` |

## Tagged Tuples for Error Handling

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

```elixir
def process_data(nil), do: {:error, :no_data}
def process_data([]), do: {:error, :empty_list}
def process_data(data) when is_list(data) do
  {:ok, Enum.map(data, &transform/1)}
end
```

## Avoid Defensive Programming

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

If the user is nil or missing a name, it's a bug that should crash and be fixed.

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| None (always first) | elixir-essentials | testing-essentials |
| None (always first) | elixir-essentials | otp-essentials |
| None (always first) | elixir-essentials | typespec-dialyzer |
| None (always first) | elixir-essentials | code-quality |
