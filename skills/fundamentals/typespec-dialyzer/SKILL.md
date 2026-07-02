---
name: typespec-dialyzer
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when adding type safety to Elixir code, writing public functions, or refactoring.
  Covers @spec, @type, Dialyxir setup, typespec best practices, and CI integration.
  Supports incremental adoption and catching type errors before production.
  Trigger words: typespec, @spec, @type, Dialyzer, Dialyxir, type safety, type checking.

---

# TypeSpec & Dialyzer

## RULES — Follow these with no exceptions

1. **Run Dialyzer in CI** — catch type errors before they reach production
2. **Start with core modules** — add typespecs incrementally, don't try to type everything at once
3. **Never ignore Dialyzer warnings without documenting why** — use `.dialyzer_ignore.exs`
4. **Add `@spec` to every public function** — document argument and return types at the boundary
5. **Define `@type t` for structs and schemas** — give each module a canonical type callers can reference
6. **Use `@opaque` for encapsulated types** — hide the internal representation from callers
7. **Cache the PLT in CI** — never rebuild the persistent lookup table on every run


## Basic TypeSpecs

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User

  @spec get_user(integer()) :: User.t() | nil
  def get_user(id) do
    Repo.get(User, id)
  end

  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```


## Custom Types

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema

  @type t :: %__MODULE__{
    id: integer() | nil,
    email: String.t(),
    username: String.t(),
    role: role(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @type role :: :admin | :editor | :viewer

  @typedoc """
  Attributes for creating or updating a user.
  """
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

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t(t())
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :role, :password])
    |> validate_required([:email, :username])
  end
end
```


## Dialyxir Setup

### Add to mix.exs

```elixir
defp deps do
  [
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
  ]
end
```

### Create .dialyzer_ignore.exs

```elixir
[
  # Ignore specific warnings
  {"lib/my_app/legacy_module.ex", :unknown_type},
  
  # Ignore by pattern
  ~r/unknown_function/,
]
```

### Run Dialyzer

```bash
# First run builds the PLT
mix dialyzer

# Format output
mix dialyzer --format short

# Ignore warnings file
mix dialyzer --ignore-file .dialyzer_ignore.exs
```


## Interpreting and Fixing Dialyzer Errors

When Dialyzer reports errors, follow this cycle: **read → locate → fix → rerun**.

### Example Dialyzer Output

```text
lib/my_app/accounts.ex:12:no_return
Function create_user/1 has no local return.

lib/my_app/accounts.ex:20:call
The call MyApp.Accounts.get_user(<<"admin">>) will never return since the success
typing is (integer()) and the contract is (integer()) :: User.t() | nil.
```

### Common Error Types and Fixes

| Error | Meaning | Fix |
|-------|---------|-----|
| `no_return` | Function always raises or crashes | Widen return type or fix crash path |
| `call` | Argument type doesn't match `@spec` | Fix call site type or update spec |
| `contract_subtype` | Return type narrower than spec | Widen spec or remove unused clauses |
| `unknown_type` | Referenced type doesn't exist | Add `@type` or fix module alias |
| `unmatched_return` | Return value not handled by caller | Handle all branches explicitly |

### Fix-then-Rerun Cycle

```bash
# 1. Run with short format for readable output
mix dialyzer --format short

# 2. Fix the flagged function — correct the @spec or the implementation
# 3. Rerun to confirm fix and check for cascading errors
mix dialyzer --format short

# 4. If a warning is a known false positive, document and suppress it
#    Add the entry to .dialyzer_ignore.exs in Elixir tuple syntax, then:
mix dialyzer --ignore-file .dialyzer_ignore.exs
```


## TypeSpec Best Practices

### Union Types

```elixir
@type status :: :active | :inactive | :suspended

@spec update_status(User.t(), status()) :: {:ok, User.t()} | {:error, atom()}
```

### Parameterized Types

```elixir
@type result(success, error) :: {:ok, success} | {:error, error}

@spec divide(number(), number()) :: result(float(), :division_by_zero)
def divide(_num, 0), do: {:error, :division_by_zero}
def divide(num, denom), do: {:ok, num / denom}
```

### Opaque Types

```elixir
defmodule MyApp.Token do
  @opaque t :: %__MODULE__{value: String.t(), expires_at: DateTime.t()}

  defstruct [:value, :expires_at]

  @spec new(String.t(), DateTime.t()) :: t()
  def new(value, expires_at) do
    %__MODULE__{value: value, expires_at: expires_at}
  end
end
```


## CI Integration

```yaml
# .github/workflows/ci.yml
- name: Dialyzer
  run: |
    mix dialyzer --format short
```

### Cache PLT for Faster CI

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

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Try to type the whole codebase at once | Adopt incrementally, starting with core modules |
| Silence Dialyzer warnings inline | Document and suppress via `.dialyzer_ignore.exs` |
| Skip Dialyzer in CI | Run `mix dialyzer --format short` in CI |
| Write `any()` specs everywhere | Use precise union and parameterized types |
| Widen a `@spec` past the real success typing | Match the spec to what the function actually returns |
| Rebuild the PLT on every CI run | Cache `priv/plts` keyed on `mix.lock` |
| Leave public functions unspecced | Add `@spec` at every public boundary |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | typespec-dialyzer | code-quality |
| ecto-essentials | typespec-dialyzer | testing-essentials |

**Companion skills:**
- `code-quality` — Credo and static analysis alongside Dialyzer
- `credo-config` — configure Credo checks that complement typespecs
