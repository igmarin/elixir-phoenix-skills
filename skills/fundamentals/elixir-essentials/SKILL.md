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

# Elixir Essentials

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

✅ **Good — prefer multi-clause functions with pattern matching over if/else:**
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
|---------|-----------|-------|
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

Use `!` suffix for functions that raise on failure. Prefer the non-bang variant in application logic; use bang in tests or when failure is truly unrecoverable.

## Early Returns

```elixir
def process_data(nil), do: {:error, :no_data}
def process_data([]), do: {:error, :empty_list}
def process_data(data) when is_list(data) do
  {:ok, Enum.map(data, &transform/1)}
end
```

## Avoid Defensive Programming

✅ **Good (trust your types):**
```elixir
def get_username(%User{name: name}), do: name
```

## Integration

Successor skills to apply after this one:
- [testing-essentials](../../testing/testing-essentials/SKILL.md)
- [otp-essentials](../otp-essentials/SKILL.md)
- [typespec-dialyzer](../typespec-dialyzer/SKILL.md)
- [code-quality](../../quality/code-quality/SKILL.md)

---

## When Not to Use

- Phoenix/LiveView application context — use the relevant Phoenix/LiveView skill instead
- OTP patterns (GenServer, Supervisor, Agent) — use `otp-essentials` instead
- Database operations — use `ecto-essentials` instead
- Type specifications or Dialyzer integration — use `typespec-dialyzer` instead
