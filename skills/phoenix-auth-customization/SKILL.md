---
name: phoenix-auth-customization
type: atomic
license: MIT
description: >
  MANDATORY when extending phx.gen.auth with custom fields. Invoke before adding usernames, profiles,
  or custom registration fields. Covers migrations, schema updates, fixture updates, form changes,
  and confirmation patterns.
  Trigger words: phx.gen.auth, custom fields, registration, username, profile, auth customization.
metadata:
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix Auth Customization

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill when extending `phx.gen.auth` with custom fields.

## RULES — Follow these with no exceptions

1. **Never modify generated auth migrations** — create separate migrations for custom fields
2. **Update `registration_changeset` to cast and validate new fields** — don't create a separate changeset
3. **Update test fixtures when adding required fields** — missing fixture fields cause cryptic test failures
4. **Confirm users in test fixtures for password-based auth** — set `confirmed_at` or tests will fail
5. **Update both the registration form AND the `save/2` handler** — the form must send the field
6. **Use `unique_constraint` + database unique index for uniqueness** — never validate in application code alone

---

## Running phx.gen.auth

```bash
# Generate auth with LiveView (recommended)
mix phx.gen.auth Accounts User users

# This creates:
# - Migration: priv/repo/migrations/*_create_users_auth_tables.exs
# - Schema: lib/my_app/accounts/user.ex
# - Context: lib/my_app/accounts.ex
# - LiveViews: lib/my_app_web/live/user_*_live.ex
# - Plugs: lib/my_app_web/user_auth.ex
```

---

## Adding Custom Fields

### Step 1: Create a Separate Migration

```bash
mix ecto.gen.migration add_username_to_users
```

```elixir
defmodule MyApp.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :string, null: false
    end

    create unique_index(:users, [:username])
  end
end
```

### Step 2: Update the Schema

```elixir
defmodule MyApp.Accounts.User do
  schema "users" do
    field :email, :string
    field :username, :string  # Add new field
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime

    timestamps()
  end

  # Update registration_changeset to include username
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :password])
    |> validate_required([:username])
    |> validate_username()
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores"
    )
    |> validate_length(:username, min: 3, max: 30)
    |> unsafe_validate_unique(:username, MyApp.Repo)
    |> unique_constraint(:username)
  end
end
```

### Step 3: Update Test Fixtures

```elixir
def user_fixture(attrs \\ %{}) do
  {:ok, user} =
    attrs
    |> Enum.into(%{
      email: "user#{System.unique_integer([:positive])}@example.com",
      username: "user#{System.unique_integer([:positive])}",  # Add username
      password: "hello world!",
      confirmed_at: DateTime.utc_now(:second)  # Confirm for tests
    })
    |> MyApp.Accounts.register_user()

  user
end
```

### Step 4: Update the Registration Form

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:username]} type="text" label="Username" />
  <.input field={@form[:email]} type="email" label="Email" />
  <.input field={@form[:password]} type="password" label="Password" />

  <:actions>
    <.button>Register</.button>
  </:actions>
</.simple_form>
```

---

## Common Pitfalls

❌ **Don't** modify generated auth migrations
❌ **Don't** forget to update test fixtures
❌ **Don't** forget to confirm users in fixtures
❌ **Don't** forget to update both form and handler
❌ **Don't** validate uniqueness in application code alone

✅ **Do** create separate migrations for custom fields
✅ **Do** update `registration_changeset`
✅ **Do** update test fixtures with all required fields
✅ **Do** set `confirmed_at` in fixtures
✅ **Do** use `unique_constraint` + database index

## Integration

| Skill | When to chain |
|-------|---------------|
| **phoenix-liveview-auth** | For LiveView authentication patterns |
| **ecto-changeset-patterns** | For changeset composition |
| **testing-essentials** | For testing patterns |
