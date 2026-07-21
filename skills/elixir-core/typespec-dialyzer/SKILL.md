---
name: typespec-dialyzer
type: atomic
tags: [atomic, elixir-core]
license: MIT
description: >
  Use when adding type safety to Elixir code, writing public functions, or refactoring.
  Specs document FCIS boundaries: pure core inputs/outputs and edge effects via tagged tuples.
  Covers @spec, @type, Dialyxir setup, ignore files, CI PLT cache. Trigger words: typespec,
  @spec, @type, Dialyzer, Dialyxir, type safety, type checking.
---

# TypeSpec & Dialyzer

Types make **data shapes and railway returns** explicit — especially at module boundaries — so pure core and shell stay honest.

Canonical FP bar: [`docs/fcis-engineering-rules.md`](../../../docs/fcis-engineering-rules.md).

## RULES — no exceptions

1. **`@spec` every public function** — especially context/shell APIs and pure core entry points
2. **`@type t` for structs/schemas** — match real field types (`NaiveDateTime.t() | nil` for default timestamps)
3. **Tagged-tuple success typing** — `{:ok, t()} | {:error, reason()}` for fallible ops
4. **Run Dialyzer in CI** with PLT cache
5. **Never ignore warnings silently** — document in `.dialyzer_ignore.exs` via `ignore_warnings` config
6. **Incremental adoption** — core modules first
7. **No `any()` as a habit** — prefer unions and parameterized result types
8. **Specs match reality** — do not widen past success typing to silence Dialyzer

## Specs at the FCIS boundary

```elixir
defmodule MyApp.Orders.Pricing do
  @type line :: %{amount: non_neg_integer()}
  @type order :: %{lines: [line()]}

  @doc "Pure core — no side effects."
  @spec total(order()) :: non_neg_integer()
  def total(%{lines: lines}), do: Enum.reduce(lines, 0, &(&1.amount + &2))
end

defmodule MyApp.Orders do
  alias MyApp.Accounts.User
  alias MyApp.Repo

  @type id :: pos_integer()

  @spec get_user(id()) :: User.t() | nil
  def get_user(id), do: Repo.get(User, id)

  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

## Struct types that match the schema

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  @type t :: %__MODULE__{
          id: integer() | nil,
          email: String.t(),
          username: String.t(),
          role: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  # When using Ecto.Enum, prefer: @type role :: :admin | :editor | :viewer
  @type role :: String.t()

  @type attrs :: %{
          optional(:email) => String.t(),
          optional(:username) => String.t(),
          optional(:role) => role(),
          optional(:password) => String.t()
        }

  schema "users" do
    field :email, :string
    field :username, :string
    field :role, :string
    field :password, :string, virtual: true
    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :role, :password])
    |> validate_required([:email, :username])
  end
end
```

## Result types (railway)

```elixir
@type result(ok, err) :: {:ok, ok} | {:error, err}

@spec divide(number(), number()) :: result(float(), :division_by_zero)
def divide(_n, 0), do: {:error, :division_by_zero}
def divide(n, d), do: {:ok, n / d}

@type status :: :active | :inactive | :suspended
@spec update_status(User.t(), status()) :: {:ok, User.t()} | {:error, atom()}
```

## Opaque types for encapsulation

```elixir
defmodule MyApp.Token do
  @opaque t :: %__MODULE__{value: String.t(), expires_at: DateTime.t()}
  defstruct [:value, :expires_at]

  @spec new(String.t(), DateTime.t()) :: t()
  def new(value, expires_at), do: %__MODULE__{value: value, expires_at: expires_at}
end
```

## Dialyxir setup

```elixir
# mix.exs deps
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
```

```elixir
# config/config.exs (or config/dev.exs)
config :dialyxir,
  ignore_warnings: ".dialyzer_ignore.exs"
```

```elixir
# .dialyzer_ignore.exs
[
  {"lib/my_app/legacy_module.ex", :unknown_type},
  ~r/unknown_function/
]
```

```bash
mix dialyzer                 # builds PLT on first run
mix dialyzer --format short
mix dialyzer --format ignore_file   # generate ignore entries
```

Do **not** pass a non-existent `--ignore-file` flag to `mix dialyzer`; configure `ignore_warnings` instead.

## Reading errors

| Error | Meaning | Fix |
|-------|---------|-----|
| `no_return` | Always raises/crashes | Fix path or return type |
| `call` | Arg does not match spec | Fix caller or spec |
| `contract_subtype` | Narrower return than spec | Align spec/impl |
| `unknown_type` | Missing `@type` / alias | Define or import type |
| `unmatched_return` | Caller ignores returns | Pattern match all branches |

```bash
mix dialyzer --format short
# fix → rerun until clean or documented ignore
```

## CI + PLT cache

```yaml
- name: Cache PLT
  uses: actions/cache@6f8efc29b200d32929f49075959781ed54ec270c # v3
  with:
    path: priv/plts
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
    restore-keys: ${{ runner.os }}-mix-

- name: Dialyzer
  run: mix dialyzer --format short
```

## Common pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Spec `map()` everywhere at the core | Parse to struct/typed attrs at the edge |
| `DateTime.t()` for default `timestamps()` | `NaiveDateTime.t() \| nil` (or match your schema) |
| Atom role type with `:string` field | String type or `Ecto.Enum` + atom type together |
| `any()` to silence Dialyzer | Fix types or document ignore |
| Rebuild PLT every CI run | Cache `priv/plts` on `mix.lock` |
| Untyped public context APIs | `@spec` with `{:ok, _} \| {:error, _}` |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | typespec-dialyzer | code-quality |
| ecto-essentials | typespec-dialyzer | testing-essentials |

**Companion:** `code-quality`, `credo-config`.
