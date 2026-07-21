# FCIS Engineering Rules

**Pragmatic Functional Programming** for this repository — not academic FP.

> **Functional Core, Imperative Shell (FCIS):** pure functions for business rules and data transforms; side effects (DB, HTTP, processes, disk) only at the edge.

## Explicit rejects

Do **not** introduce:

- Monad libraries or custom category-theory abstractions
- Process trees used as code organization (modules are for organization)
- Clever FP that hurts idiomatic Elixir readability

Idiomatic Elixir always wins.

---

## The six rules

### 1. Functional Core, Imperative Shell

**Rule:** Keep core logic (business rules, calculations, transformations) in pure functions on plain modules/structs. Push side effects to boundaries (controllers, LiveViews, workers, plugs).

**Asset impact:** Good examples separate pure data work from `Repo` / HTTP / process calls so unit tests stay fast and side-effect free.

```elixir
# ✅ Pure core
def total(%Order{lines: lines}), do: Enum.reduce(lines, 0, &(&1.amount + &2))

# ✅ Imperative shell
def checkout(order_id) do
  with {:ok, order} <- Orders.fetch(order_id),
       total <- Orders.total(order),
       {:ok, charge} <- Payments.charge(order, total) do
    {:ok, charge}
  end
end
```

### 2. Guards and pattern matching over control flow

**Rule:** Prefer multi-clause functions and guards over nested `if` / `unless` / deep `case`.

**Asset impact:** Teach dispatch through function heads so the runtime chooses the clause.

```elixir
# Pure response mapper (not a behaviour callback — no @impl needed)

# ❌
def handle_response(%{status: s} = r) do
  if s == 200, do: {:ok, r.body}, else: {:error, :bad_status}
end

# ✅
def handle_response(%{status: 200, body: body}), do: {:ok, body}
def handle_response(%{status: status}), do: {:error, {:bad_status, status}}
```

### 3. Railway-oriented flow via tagged tuples and `with`

**Rule:** Normalize fallible returns to `{:ok, result} | {:error, reason}`. Chain with `with`. Handle errors in explicit clauses, not bloated conditionals.

**Asset impact:** Show happy-path aggregation in `with`; normalize errors at the edge when needed.

```elixir
def create_post(attrs) do
  with {:ok, attrs} <- validate(attrs),
       {:ok, post} <- Repo.insert(change_post(attrs)) do
    {:ok, post}
  end
end
```

### 4. Pipe linearity (`|>`) and composition

**Rule:** Pipes read as one-direction transforms. The first argument is always the subject. Prefer named single-purpose functions.

**Asset impact:** Discourage `|> case do` and pipes into anonymous functions.

```elixir
# ❌
params |> case do
  %{"id" => id} -> Repo.get(User, id)
  _ -> nil
end

# ✅
params
|> fetch_user_id()
|> Users.get()
```

### 5. Explicit structs and early parsing

**Rule:** FP needs predictable shapes. Parse untyped maps into structs or `Ecto.Changeset` **at the boundary** before pure core (“parse, don’t validate” as far as practical).

**Asset impact:** Examples convert external input once, then pass typed data inward.

```elixir
def create(params) when is_map(params) do
  params
  |> Registration.changeset()
  |> apply_action(:insert)
  |> case do
    {:ok, data} -> register(data)   # pure-ish core with known shape
    {:error, cs} -> {:error, cs}
  end
end
```

### 6. Process independence and concurrency boundaries

**Rule:** GenServer / Task / Agent exist for concurrency, state, and isolation — not module layout. Callbacks stay thin; pure functions do the work.

**Asset impact:** Show pure modules called from `handle_call` / `perform/1` / `handle_event`.

```elixir
@impl true
def handle_call({:quote, items}, _from, state) do
  {:reply, Pricing.quote(items), state}  # Pricing is pure
end
```

---

## Framework patterns

| Framework | Non-FP / anti-pattern | Idiomatic FCIS pattern |
|-----------|----------------------|-------------------------|
| **Ecto** | DB mutations mixed with business calculation | Pure functions build `Changeset` / `Multi`; execute once at the edge |
| **LiveView** | Heavy logic inside `handle_event/3` | Event handler delegates to pure domain; pipe into assigns |
| **Oban** | Worker owns complex state and ad-hoc retries | `perform/1` is an edge runner: fetch → pure core → `{:ok, _}` / `{:error, _}` |

### Ecto

```elixir
# Pure-ish: builds Multi, no execute
def transfer_multi(from_id, to_id, amount) do
  Multi.new()
  |> Multi.run(:debit, fn _, _ -> Accounts.debit(from_id, amount) end)
  |> Multi.run(:credit, fn _, _ -> Accounts.credit(to_id, amount) end)
end

# Edge
def transfer(from_id, to_id, amount), do: Repo.transaction(transfer_multi(from_id, to_id, amount))
```

### LiveView

```elixir
@impl true
def handle_event("save", %{"post" => params}, socket) do
  case Blog.create_post(params) do  # domain/context owns the work
    {:ok, post} -> {:noreply, assign(socket, :post, post)}
    {:error, cs} -> {:noreply, assign(socket, :form, to_form(cs))}
  end
end
```

### Oban

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"post_id" => id}}) do
  with {:ok, post} <- Blog.fetch_post(id),
       {:ok, _} <- Blog.publish(post) do
    :ok
  end
end
```

---

## How skills use this doc

- Atomic skills: fold these rules into **RULES** and good/bad examples.
- Assets: short snippets that show pure core vs edge.
- Playbooks: enforce process (tests, gates); they **link** here rather than re-teaching FP.

See also: [taxonomy.md](taxonomy.md), [playbooks.md](playbooks.md).
