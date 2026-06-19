---
name: typespec-dialyzer
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for adding type safety to Elixir code. Invoke before writing public functions or refactoring.
  Covers @spec, @type, Dialyxir setup, typespec best practices, and CI integration.
  Critical for refactoring discipline and catching type errors at compile time.
  Trigger words: typespec, @spec, @type, Dialyzer, Dialyxir, type safety, type checking.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# TypeSpec & Dialyzer

TypeSpecs and Dialyzer provide static analysis for Elixir, catching type errors before runtime.

## RULES — Follow these with no exceptions

1. **Add `@spec` to all public functions** — typespecs are documentation and enable Dialyzer analysis
2. **Define custom types with `@type`** — make complex types readable and reusable
3. **Use `@typedoc` for custom types** — document what the type represents
4. **Run Dialyzer in CI** — catch type errors before they reach production
5. **Use `@spec` over documentation alone** — typespecs are machine-checkable
6. **Start with core modules** — add typespecs incrementally, don't try to type everything at once
7. **Use Dialyxir's `--format short`** — easier to read and fix errors

---

## Basic TypeSpecs

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User

  @doc """
  Gets a user by ID.

  ## Examples

      iex> get_user(1)
      %User{}

      iex> get_user(999)
      nil

  """
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

---

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

---

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
# First run builds the PLT (slow)
mix dialyzer

# Subsequent runs are fast
mix dialyzer

# Format output
mix dialyzer --format short

# Ignore warnings file
mix dialyzer --ignore-file .dialyzer_ignore.exs
```

---

## TypeSpec Best Practices

### Use Built-in Types

```elixir
@spec process(String.t()) :: :ok | {:error, atom()}
@spec list_users() :: [User.t()]
@spec get_user(integer()) :: User.t() | nil
@spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
```

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

---

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
  uses: actions/cache@v3
  with:
    path: priv/plts
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
    restore-keys: ${{ runner.os }}-mix-

- name: Dialyzer
  run: mix dialyzer --format short
```

---

## Common Pitfalls

❌ **Don't** skip `@spec` on public functions
❌ **Don't** ignore Dialyzer warnings without documenting why
❌ **Don't** try to add typespecs to everything at once
❌ **Don't** forget to run Dialyzer in CI
❌ **Don't** use `any()` as a catch-all — be specific

✅ **Do** add `@spec` to all public functions
✅ **Do** define custom types with `@type`
✅ **Do** use `@typedoc` for complex types
✅ **Do** run Dialyzer in CI
✅ **Do** add typespecs incrementally

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **elixir-essentials** | For general Elixir patterns |
| **code-quality** | For overall code quality |
| **credo-config** | For style and linting |
