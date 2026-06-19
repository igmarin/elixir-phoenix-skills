---
name: ecto-essentials
type: atomic
license: MIT
description: >
  MANDATORY for ALL database work. Invoke before modifying schemas, queries, or migrations.
  Covers schema definition, changesets, query composition, preloading, transactions,
  associations, migrations, upserts, dynamic queries, and the context pattern.
  Trigger words: Ecto, schema, changeset, migration, Repo, query, preload, association, belongs_to, has_many.
metadata:
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Ecto Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before modifying ANY schema, query, or migration.

## RULES — Follow these with no exceptions

1. **Always use changesets** for inserts and updates — never pass raw maps to Repo
2. **Preload associations** before accessing them — avoid N+1 queries
3. **Use transactions** for multi-step operations that must succeed together
4. **Add database constraints** (unique_index, foreign_key, check_constraint) AND changeset validations
5. **Use contexts** for database access — never call Repo directly from web layer
6. **Add indexes** on foreign keys and frequently queried fields
7. **Use `timestamps()`** in every schema — track when records were created/updated
8. **Use `Ecto.Multi`** for complex multi-step operations instead of nested `Repo.transaction`
9. **Parameterize all user input in queries** — never interpolate values into SQL fragments

---

## Schema Definition

Define schemas with proper types and associations.

```elixir
defmodule MyApp.Media.Image do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field :title, :string
    field :description, :string
    field :filename, :string
    field :file_path, :string
    field :content_type, :string
    field :file_size, :integer

    belongs_to :folder, MyApp.Media.Folder

    timestamps()
  end
end
```

## Changesets

Always use changesets for data validation and casting.

```elixir
def changeset(image, attrs) do
  image
  |> cast(attrs, [:title, :description, :filename, :file_path, :content_type, :file_size, :folder_id])
  |> validate_required([:title, :filename, :file_path, :content_type, :file_size])
  |> validate_length(:title, min: 1, max: 255)
  |> validate_inclusion(:content_type, ["image/jpeg", "image/png", "image/gif"])
  |> validate_number(:file_size, greater_than: 0, less_than: 10_000_000)
  |> foreign_key_constraint(:folder_id)
end
```

## Query Composition

Build queries composably using `Ecto.Query`.

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
  |> where([i], ilike(i.title, ^search) or ilike(i.description, ^search))
  |> Repo.all()
end
```

## Preloading Associations

Use `preload` to avoid N+1 queries.

❌ **Bad — N+1 queries:**
```elixir
images = Repo.all(Image)
Enum.each(images, fn image -> image.folder.name end)  # Query per image!
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

Use `Repo.transaction` for operations that must succeed together.

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

## Insert and Update

```elixir
def create_image(attrs) do
  %Image{}
  |> Image.changeset(attrs)
  |> Repo.insert()
end

def update_image(%Image{} = image, attrs) do
  image
  |> Image.changeset(attrs)
  |> Repo.update()
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

## Associations

```elixir
# Parent schema
defmodule MyApp.Media.Folder do
  use Ecto.Schema

  schema "folders" do
    field :name, :string
    has_many :images, MyApp.Media.Image

    timestamps()
  end
end

# Child schema
defmodule MyApp.Media.Image do
  use Ecto.Schema

  schema "images" do
    field :title, :string
    belongs_to :folder, MyApp.Media.Folder

    timestamps()
  end
end
```

## Building Associations

```elixir
def add_image_to_folder(folder, image_attrs) do
  folder
  |> Ecto.build_assoc(:images)
  |> Image.changeset(image_attrs)
  |> Repo.insert()
end
```

## Dynamic Queries

Build queries dynamically based on filters.

```elixir
def list_images(filters) do
  Image
  |> apply_filters(filters)
  |> Repo.all()
end

defp apply_filters(query, filters) do
  Enum.reduce(filters, query, fn
    {:folder_id, folder_id}, query ->
      where(query, [i], i.folder_id == ^folder_id)

    {:search, term}, query ->
      where(query, [i], ilike(i.title, ^"%#{term}%"))

    {:min_size, size}, query ->
      where(query, [i], i.file_size >= ^size)

    _, query ->
      query
  end)
end
```

## Aggregations

```elixir
def count_images_by_folder do
  Image
  |> group_by([i], i.folder_id)
  |> select([i], {i.folder_id, count(i.id)})
  |> Repo.all()
  |> Map.new()
end

def total_storage_used do
  Image
  |> select([i], sum(i.file_size))
  |> Repo.one()
end
```

## Migrations

Write clear, reversible migrations.

```elixir
defmodule MyApp.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :title, :string, null: false
      add :description, :text
      add :filename, :string, null: false
      add :file_path, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :folder_id, references(:folders, on_delete: :nilify_all)

      timestamps()
    end

    create index(:images, [:folder_id])
    create index(:images, [:inserted_at])
  end
end
```

## Unique Constraints

Add unique constraints in schema AND migration.

```elixir
# Migration
create unique_index(:folders, [:name])

# Schema changeset
def changeset(folder, attrs) do
  folder
  |> cast(attrs, [:name])
  |> validate_required([:name])
  |> unique_constraint(:name)
end
```

## Context Pattern

Organize database operations in contexts.

```elixir
defmodule MyApp.Media do
  alias MyApp.Media.{Image, Folder}
  alias MyApp.Repo

  def list_images, do: Repo.all(Image)

  def get_image!(id), do: Repo.get!(Image, id)

  def create_image(attrs) do
    %Image{}
    |> Image.changeset(attrs)
    |> Repo.insert()
  end

  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
  end

  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end
end
```

---

## Common Pitfalls

❌ **Don't** pass raw maps to `Repo.insert/1` — always use changesets
❌ **Don't** access associations without preloading — causes N+1 queries
❌ **Don't** call Repo directly from LiveViews or controllers — use contexts
❌ **Don't** forget indexes on foreign keys
❌ **Don't** combine schema changes and data backfill in one migration
❌ **Don't** interpolate user input into SQL fragments — use `^` parameterization

✅ **Do** use changesets for all inserts/updates
✅ **Do** preload associations before accessing them
✅ **Do** use `Ecto.Multi` for complex multi-step operations
✅ **Do** add both changeset validations AND database constraints
✅ **Do** wrap database operations in context modules
✅ **Do** write reversible migrations using `change/0`

## Integration

| Skill | When to chain |
|-------|---------------|
| **testing-essentials** | Before writing schema or context tests |
| **ecto-changeset-patterns** | When working with advanced changeset patterns |
| **ecto-nested-associations** | When working with cast_assoc, cast_embed, or nested data |
| **phoenix-liveview-essentials** | When querying data for LiveViews |
| **security-essentials** | When handling user input in queries |

See `agents/ecto-conventions.md` for comprehensive Ecto patterns and best practices.
