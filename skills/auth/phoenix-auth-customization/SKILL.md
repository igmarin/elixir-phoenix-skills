---
name: phoenix-auth-customization
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY when extending phx.gen.auth with custom fields. Invoke before adding usernames, profiles,
  or custom registration fields. Covers migrations, schema updates, fixture updates, form changes,
  and confirmation patterns.
  Trigger words: phx.gen.auth, custom fields, registration, username, profile, auth customization.

---

# Phoenix Auth Customization

Use this skill when extending `phx.gen.auth` with custom fields.

## RULES — Follow these with no exceptions

1. **Never modify generated auth migrations** — create separate migrations for custom fields
2. **Update `registration_changeset` to cast and validate new fields** — don't create a separate changeset
3. **Update test fixtures when adding required fields** — missing fixture fields cause cryptic test failures
4. **Confirm users in test fixtures for password-based auth** — set `confirmed_at` or tests will fail
5. **Update both the registration form AND the `save/2` handler** — the form must send the field
6. **Use `unique_constraint` + database unique index for uniqueness** — never validate in application code alone


## Running phx.gen.auth

```bash
# Generate auth with LiveView (recommended)
mix phx.gen.auth Accounts User users
```


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

```bash
# Run migration and verify success before proceeding
mix ecto.migrate
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

```bash
# Verify fixtures pass before updating forms
mix test
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


## Additional Patterns

### Profile Fields

For optional fields like `display_name` or `avatar_url`, follow the same migration → schema → fixture sequence as above. Differences from required fields:

- Omit `null: false` in the migration column definition.
- Omit `validate_required` for that field in the changeset.

### Confirmation Patterns

`phx.gen.auth` generates a `confirmed_at` field and an email-confirmation flow automatically.

- **In tests**: set `confirmed_at: DateTime.utc_now(:second)` in fixtures (Rule 4) so tests are not blocked by the confirmation gate.
- **In production**: users must click the confirmation link before `confirmed_at` is populated. Guard LiveViews with `require_authenticated_user` and check `confirmed_at` explicitly where needed.

### Extending Other Changesets

`email_changeset` and `password_changeset` follow the same cast-then-validate pattern as `registration_changeset`. Never add a parallel changeset; extend the existing one.
