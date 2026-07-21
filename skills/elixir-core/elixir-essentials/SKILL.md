---
name: elixir-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL Elixir code changes. Invoke before writing any .ex or .exs file.
  Enforces pragmatic Functional Core, Imperative Shell (FCIS): pure core modules,
  pattern matching, tagged tuples + with, linear pipes, explicit structs at boundaries,
  and thin edges. No monads or academic FP. Trigger words: elixir, FCIS, pattern matching,
  pipe, with, error handling, tagged tuples, guards, pure functions.
metadata:
  version: "1.0.0"
  user-invocable: "true"
---

# Elixir Essentials

Use this skill before writing **any** `.ex` or `.exs` file.

Canonical standard: [`docs/fcis-engineering-rules.md`](../../../docs/fcis-engineering-rules.md).

**Quick reference:** [FCIS checklist](assets/fcis_checklist.md) — run before shipping `.ex` / `.exs` files.

## Quick Reference

| Concern | Do this |
|---------|---------|
| Business rules | Pure modules — no `Repo` / HTTP / process sends |
| Fallible flows | `{:ok, _} \| {:error, _}` + `with` |
| Control flow | Multi-clause + guards, not nested `if` |
| Transforms | Linear pipes; named steps |
| External input | Parse to struct/changeset at the edge |
| Callbacks | `@impl true`; keep thin |
| Checklist | [assets/fcis_checklist.md](assets/fcis_checklist.md) |


## RULES — Follow these with no exceptions

1. **Functional Core, Imperative Shell** — pure functions for rules/transforms; DB/HTTP/process/IO only at edges
2. **Pattern match and guards** over nested `if` / `unless` / deep `case`
3. **Tagged tuples** — fallible ops return `{:ok, result} | {:error, reason}`; chain with `with`
4. **Linear pipes** — subject first; named steps; no `|> case do` or pipes into anonymous fns
5. **Parse at the boundary** — coerce maps into structs/changesets before pure core
6. **`@impl true`** on every behaviour callback
7. **Immutability** — never mutate data in place
8. **Predicates end with `?`**, bang (`!`) only for dangerous/raising ops
9. **No `String.to_atom/1` on user input** — prefer strings; allowlist before any atom conversion
10. **No monads / category-theory libs** — idiomatic Elixir only
11. **`@doc` / `@moduledoc`** on public APIs
12. **Prefer `for`** over chaining 3+ `Enum` passes when one pass is clearer

## 1. Functional Core, Imperative Shell

❌ **Bad:** business rules mixed with side effects

```elixir
def checkout(order_id) do
  order = Repo.get!(Order, order_id)
  total = Enum.reduce(order.lines, 0, &(&1.amount + &2))
  Payments.charge(order, total)
end
```

✅ **Good:** pure core + thin shell

```elixir
defmodule MyApp.Orders.Pricing do
  def total(%{lines: lines}), do: Enum.reduce(lines, 0, &(&1.amount + &2))

  def discount(total, :vip) when total > 100, do: div(total, 10)
  def discount(_total, _tier), do: 0
end

defmodule MyApp.Orders do
  alias MyApp.Orders.Pricing

  def checkout(order_id) do
    with {:ok, order} <- fetch(order_id),
         total <- Pricing.total(order),
         {:ok, charge} <- Payments.charge(order, total) do
      {:ok, charge}
    end
  end
end
```

## 2. Pattern matching & guards

❌ **Bad:** nested conditionals

```elixir
def handle_response(%{status: s} = r) do
  if s == 200, do: {:ok, r.body}, else: {:error, :bad_status}
end
```

✅ **Good:** multi-clause dispatch (pure mapper — not a behaviour callback)

```elixir
def handle_response(%{status: 200, body: body}), do: {:ok, body}
def handle_response(%{status: 404}), do: {:error, :not_found}
def handle_response(%{status: status}), do: {:error, {:bad_status, status}}

def calculate(x) when is_integer(x) and x > 0, do: x * 2
def calculate(_), do: {:error, :invalid_input}
```

## 3. Railway flow: tagged tuples + `with`

❌ **Bad:** nested `case`

```elixir
def create_post(params) do
  case validate(params) do
    {:ok, attrs} ->
      case Repo.insert(change_post(attrs)) do
        {:ok, post} -> {:ok, post}
        error -> error
      end
    error -> error
  end
end
```

✅ **Good:** `with` for sequential fallible steps

```elixir
def create_post(params) do
  with {:ok, attrs} <- validate(params),
       {:ok, post} <- Repo.insert(change_post(attrs)) do
    {:ok, post}
  end
end
```

✅ **Good:** optional `else` for normalized edge errors

```elixir
def transfer(from_id, to_id, amount) do
  with {:ok, from} <- get_account(from_id),
       {:ok, to} <- get_account(to_id),
       :ok <- ensure_funds(from, amount),
       {:ok, _} <- debit(from, amount),
       {:ok, _} <- credit(to, amount) do
    {:ok, :complete}
  else
    {:error, :insufficient_funds} -> {:error, :insufficient_funds}
    {:error, :not_found} -> {:error, :not_found}
    other -> {:error, {:transfer_failed, other}}
  end
end
```

## 4. Pipe linearity

❌ **Bad:** pipe into `case`

```elixir
params
|> case do
  %{"id" => id} -> Repo.get(User, id)
  _ -> nil
end
```

✅ **Good:** linear named steps

```elixir
params
|> Map.fetch!("id")
|> Users.get()
```

Pipes should read as **one subject transformed**. Extract named functions instead of long anonymous steps.

## 5. Explicit shapes at the boundary

❌ **Bad:** untyped maps deep in core logic

```elixir
def register(params) do
  email = params["email"]
  create_user(%{email: email, role: String.to_atom(params["role"])})
end
```

✅ **Good:** parse once, then use a known shape

```elixir
def register(params) when is_map(params) do
  case Registration.changeset(params) |> Ecto.Changeset.apply_action(:insert) do
    {:ok, data} -> create_user(data)
    {:error, cs} -> {:error, cs}
  end
end
```

## Naming

| Element | Convention | Example |
|---------|------------|---------|
| Modules | `PascalCase` | `MyApp.Accounts.User` |
| Functions / vars | `snake_case` | `create_user/1` |
| Predicates | end with `?` | `valid?/1` |
| Raising | end with `!` | `get_user!/1` — avoid in app logic |

## List work

❌ **Bad:** three passes over the same list

```elixir
list
|> Enum.map(&transform/1)
|> Enum.filter(&valid?/1)
|> Enum.map(&format/1)
```

✅ **Good:** one pass when clearer

```elixir
for item <- list,
    transformed = transform(item),
    valid?(transformed) do
  format(transformed)
end
```

## Atoms & user input

| ❌ Don't | ✅ Do |
|----------|-------|
| `String.to_atom(user_input)` | Keep strings, or allowlist then convert |
| Blind `to_existing_atom/1` on arbitrary input | Allowlist first — unknown values raise `ArgumentError` |

## Let it crash

Do not write defensive code for impossible states after you have validated at the boundary. Supervisors recover process failures; pure code should not hide bugs with broad `rescue`.

## Common pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Business math mixed with `Repo` | Pure module + thin context shell |
| Nested `if` / `case` for sequential fallible steps | `with` + tagged tuples |
| `|> case do` | Named step or multi-clause function |
| Mutate maps/lists in place | Return new values |
| Skip `@impl true` on callbacks | Annotate every callback |
| Monads / custom FP frameworks | Idiomatic Elixir |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| None (always first) | elixir-essentials | otp-essentials |
| None (always first) | elixir-essentials | testing-essentials |
| None (always first) | elixir-essentials | typespec-dialyzer |

**See also:** `docs/fcis-engineering-rules.md`, `otp-essentials`, domain skills (Ecto/LiveView/Oban keep edges thin).
