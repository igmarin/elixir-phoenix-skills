---
name: ecto-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL database work. Invoke before modifying schemas, queries, or migrations.
  Covers schema definition, changesets, query composition, preloading, transactions,
  associations, migrations, upserts, dynamic queries, and the context pattern.
  Trigger words: Ecto, schema, changeset, migration, Repo, query, preload, association, belongs_to, has_many.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Ecto Essentials

Use this skill before modifying ANY schema, query, or migration.

## RULES — Follow these with no exceptions

1. **Add database constraints** (unique_index, foreign_key, check_constraint) AND changeset validations — both layers are required
2. **Add indexes** on foreign keys and frequently queried fields — never omit indexes on foreign keys
3. **Parameterize all user input in queries** — never interpolate values into SQL fragments, always use `^`
4. **Never combine schema changes and data backfill** in the same migration

---

## Schema Definition

Define schemas with proper types and associations. The example below shows a child schema with `belongs_to`; a parent schema uses `has_many` in the same pattern (see `Folder` in the migration section for reference).

```elixir
defmodule MyApp.Media.Image do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field :title, :string
    field :filename, :string
    field :content_type, :string

    belongs_to :folder, MyApp.Media.Folder  # parent uses has_many :images, MyApp.Media.Image

    timestamps()
  end

  def changeset(image, attrs) do
    image
    |> cast(attrs, [:title, :filename, :content_type, :folder_id])
    |> validate_required([:title, :filename, :content_type])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:content_type, ["image/jpeg", "image/png", "image/gif"])
    |> foreign_key_constraint(:folder_id)
  end
end
```

## Query Composition

```elixir
import Ecto.Query

def list_images_by_folder(folder_id) do
  Image
  |> where([i], i.folder_id == ^folder_id)
  |> order_by([i], desc: i.inserted_at)
  |> Repo.all()
end

def search_images(query_string) do
  search = "%#{query_string}%"

  Image
  |> where([i], ilike(i.title, ^search))
  |> Repo.all()
end
```

## Preloading Associations

❌ **Bad — N+1 queries:**
```elixir
images = Repo.all(Image)
Enum.each(images, fn image -> image.folder.name end)
```

✅ **Good — single query with preload:**
```elixir
images =
  Image
  |> preload(:folder)
  |> Repo.all()

Enum.each(images, fn image -> image.folder.name end)
```

## Transactions

```elixir
def transfer_images(image_ids, from_folder_id, to_folder_id) do
  Repo.transaction(fn ->
    with {:ok, from_folder} <- get_folder(from_folder_id),
         {:ok, to_folder} <- get_folder(to_folder_id),
         {count, nil} <- update_images(image_ids, to_folder_id) do
      {:ok, count}
    else
      {:error, reason} -> Repo.rollback(reason)
      _ -> Repo.rollback(:unknown_error)
    end
  end)
end
```

### Ecto.Multi for Complex Operations

```elixir
def create_user_with_profile(user_attrs, profile_attrs) do
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:user, User.changeset(%User{}, user_attrs))
  |> Ecto.Multi.insert(:profile, fn %{user: user} ->
    Profile.changeset(%Profile{}, Map.put(profile_attrs, :user_id, user.id))
  end)
  |> Repo.transaction()
end
```

On failure, the error tuple identifies the named step: `{:error, :user, changeset, _changes}` or `{:error, :profile, changeset, _changes}`.

## Building Associations

```elixir
def add_image_to_folder(folder, image_attrs) do
  folder
  |> Ecto.build_assoc(:images)
  |> Image.changeset(image_attrs)
  |> Repo.insert()
end
```

## Upsert Operations

```elixir
def create_or_update_folder(attrs) do
  %Folder{}
  |> Folder.changeset(attrs)
  |> Repo.insert(
    on_conflict: {:replace, [:name, :updated_at]},
    conflict_target: :name
  )
end
```

## Dynamic Queries

```elixir
def list_images(filters) do
  Enum.reduce(filters, Image, fn
    {:folder_id, id}, q -> where(q, [i], i.folder_id == ^id)
    {:search, term}, q -> where(q, [i], ilike(i.title, ^"%#{term}%"))
    {:content_type, ct}, q -> where(q, [i], i.content_type == ^ct)
    _, q -> q
  end)
  |> Repo.all()
end
```

## Migrations

Write clear, reversible migrations. After writing a migration, always validate it with the steps below.

```elixir
defmodule MyApp.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :title, :string, null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :folder_id, references(:folders, on_delete: :nilify_all)

      timestamps()
    end

    create index(:images, [:folder_id])
    create index(:images, [:inserted_at])
  end
end
```

**Migration validation workflow:**
1. Run `mix ecto.migrate` — confirm it applies without errors
2. Run `mix ecto.rollback` — confirm it reverses cleanly
3. Run `mix ecto.migrate` again — confirm re-applying succeeds

### Unique Constraints

Add unique constraints in migration AND schema changeset (already shown in the Folder schema above).

```elixir
# Migration
create unique_index(:folders, [:name])
```

## Context Pattern

**Never call Repo from the web layer** (LiveViews, controllers) — all database operations belong in context modules.

```elixir
defmodule MyApp.Media do
  alias MyApp.Media.{Image, Folder}
  alias MyApp.Repo

  def create_image(attrs) do
    %Image{}
    |> Image.changeset(attrs)
    |> Repo.insert()
  end
end
```

All standard CRUD functions (`list_*`, `get_*!`, `update_*`, `delete_*`) follow the same pattern.

---

## Related Skills

- **Prerequisite:** [elixir-essentials](../../fundamentals/elixir-essentials/SKILL.md) — core Elixir patterns before working with Ecto
- **Next — changeset deep-dive:** [ecto-changeset-patterns](../ecto-changeset-patterns/SKILL.md) — advanced validations, custom constraints, and error formatting
- **Next — testing:** [testing-essentials](../testing-essentials/SKILL.md) — testing Ecto contexts and migrations

---

## When Not to Use

- **Do not invoke this skill** for simple read-only schema inspection or introspection (use `mix ecto.schema` directly instead)
- **Do not use this skill** for raw SQL queries that bypass Ecto entirely — write raw SQL in a dedicated repo method, not inline in contexts
- **Do not invoke this skill** for multi-table complex transactions — use `ecto-changeset-patterns` for `Ecto.Multi` and nested association patterns
- **Do not use this skill** for database migration planning — use `ecto-migration` persona instead for migration orchestration
