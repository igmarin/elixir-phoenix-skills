---
name: ecto-changeset-patterns
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL changeset work beyond basic CRUD. Invoke before writing multiple changesets,
  cast_assoc, or conditional validation. Covers separate changesets per operation, cast_assoc pitfalls,
  composition, conditional validation with opts, field transformations, and uniqueness validation.
  Trigger words: changeset, cast_assoc, validation, separate changesets, conditional validation, update_change.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Ecto Changeset Patterns

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY advanced changeset code.

## RULES — Follow these with no exceptions

1. **Create separate named changesets per operation** — `registration_changeset`, `email_changeset`, `password_changeset`; never overload a single `changeset/2`
2. **Never require foreign key fields in `cast_assoc` child changesets** — the parent sets them automatically
3. **Compose changesets with pipes** — each validation step is a separate function for reuse and clarity
4. **Use `unsafe_validate_unique` paired with `unique_constraint`** — never one without the other
5. **Use `update_change/3` for field transformations** — trimming, downcasing, slugifying happen in the changeset
6. **Accept `opts \\ []` for conditional validation** — allows callers to toggle validation rules
7. **Validate at the changeset level, not in context functions** — context functions should be thin wrappers

---

## Separate Changesets Per Operation

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :bio, :string

    timestamps()
  end

  # Registration — all fields, password hashing
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :password])
    |> validate_email(opts)
    |> validate_username()
    |> validate_password(opts)
  end

  # Email change — only email
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  # Password change — only password
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
    |> put_password_hash()
  end

  # Profile update — non-sensitive fields only
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :bio])
    |> validate_username()
  end
end
```

---

## cast_assoc — Critical Pitfall

❌ **Bad — `:post_id` is required but set automatically by cast_assoc:**
```elixir
def changeset(ingredient, attrs) do
  ingredient
  |> cast(attrs, [:name, :quantity, :post_id])
  |> validate_required([:name, :post_id])  # Fails!
end
```

✅ **Good — only require user-provided fields:**
```elixir
def changeset(ingredient, attrs) do
  ingredient
  |> cast(attrs, [:name, :quantity])
  |> validate_required([:name])
end
```

---

## Changeset Composition

```elixir
defp validate_email(changeset, opts) do
  changeset
  |> validate_required([:email])
  |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
  |> validate_length(:email, max: 160)
  |> maybe_validate_unique_email(opts)
end

defp validate_username(changeset) do
  changeset
  |> validate_required([:username])
  |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "only letters, numbers, and underscores")
  |> validate_length(:username, min: 3, max: 30)
  |> unsafe_validate_unique(:username, MyApp.Repo)
  |> unique_constraint(:username)
end
```

---

## Conditional Validation with opts

```elixir
def registration_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:email, :username, :password])
  |> validate_email(opts)
  |> validate_password(opts)
end

# Normal registration
def register_user(attrs) do
  %User{}
  |> User.registration_changeset(attrs)
  |> Repo.insert()
end

# In tests — skip hashing for speed
def register_user_for_test(attrs) do
  %User{}
  |> User.registration_changeset(attrs, hash_password: false, validate_email: false)
  |> Repo.insert()
end
```

---

## Field Transformations with update_change

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :username])
  |> update_change(:email, &String.downcase/1)
  |> update_change(:username, &String.trim/1)
  |> update_change(:username, &String.downcase/1)
end

# For slugs
defp generate_slug(changeset) do
  case get_change(changeset, :title) do
    nil -> changeset
    title ->
      slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
      put_change(changeset, :slug, slug)
  end
end
```

---

## Uniqueness Validation

Always pair `unsafe_validate_unique` with `unique_constraint`:

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :username])
  # Fast check — queries DB, gives immediate UI feedback
  |> unsafe_validate_unique(:email, MyApp.Repo)
  |> unsafe_validate_unique(:username, MyApp.Repo)
  # Constraint check — catches race conditions at insert time
  |> unique_constraint(:email)
  |> unique_constraint(:username)
end
```

---

## Common Pitfalls

❌ **Don't** overload a single `changeset/2` for all operations
❌ **Don't** require foreign keys in `cast_assoc` child changesets
❌ **Don't** use `unsafe_validate_unique` without `unique_constraint`
❌ **Don't** transform fields in controllers — do it in changesets
❌ **Don't** validate uniqueness in application code alone

✅ **Do** create separate named changesets per operation
✅ **Do** compose changesets with small, reusable validation functions
✅ **Do** use `opts` for conditional validation
✅ **Do** use `update_change/3` for field transformations
✅ **Do** pair `unsafe_validate_unique` with `unique_constraint`

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **ecto-essentials** | For schema and migration patterns |
| **ecto-nested-associations** | For `cast_assoc` with nested data |
| **testing-essentials** | For changeset testing patterns |
