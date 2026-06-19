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

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before modifying ANY schema, query, or migration.

## RULES — Follow these with no exceptions

1. **Add database constraints** (unique_index, foreign_key, check_constraint) AND changeset validations — both layers are required
2. **Add indexes** on foreign keys and frequently queried fields — never omit indexes on foreign keys
3. **Parameterize all user input in queries** — never interpolate values into SQL fragments, always use `^`
4. **Never combine schema changes and data backfill** in the same migration

---

## Schema Definition

Define schemas with proper types and associations.

```elixir
# Parent schema
defmodule MyApp.Media.Folder do
  use Ecto.Schema
  import Ecto.Changeset

  schema "folders" do
    field :name, :string
    has_many :images, MyApp.Media.Image

    timestamps()
  end

  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end

# Child schema
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

  def changeset(image, attrs) do
    image
    |> cast(attrs, [:title, :description, :filename, :file_path, :content_type, :file_size, :folder_id])
    |> validate_required([:title, :filename, :file_path, :content_type, :file_size])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:content_type, ["image/jpeg", "image/png", "image/gif"])
    |> validate_number(:file_size, greater_than: 0, less_than: 10_000_000)
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
  |> where([i], ilike(i.title, ^search) or ilike(i.description, ^search))
  |> Repo.all()
end
```

## Preloading Associations

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

**Transaction validation — always pattern-match the result:**
```elixir
case transfer_images(ids, from_id, to_id) do
  {:ok, {:ok, count}} -> IO.puts("Transferred #{count} images")
  {:ok, _}            -> IO.puts("Completed with unexpected shape")
  {:error, reason}    -> IO.puts("Rolled back: #{inspect(reason)}")
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

**Multi result validation — inspect named steps on failure:**
```elixir
case create_user_with_profile(u_attrs, p_attrs) do
  {:ok, %{user: user, profile: profile}} ->
    IO.puts("Created user #{user.id} and profile #{profile.id}")
  {:error, :user, changeset, _changes} ->
    IO.inspect(changeset.errors, label: "User step failed")
  {:error, :profile, changeset, _changes} ->
    IO.inspect(changeset.errors, label: "Profile step failed")
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

**Upsert validation — check whether a row was inserted or updated:**
```elixir
case create_or_update_folder(%{name: "Photos"}) do
  {:ok, folder} ->
    # folder.id is populated regardless of insert vs. update path
    IO.puts("Upserted folder #{folder.id}")
  {:error, changeset} ->
    IO.inspect(changeset.errors, label: "Upsert failed")
end
```

## Dynamic Queries

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
      where(query, [i], ilike(i.title, ^"#{term}"))

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

Write clear, reversible migrations. After writing a migration, always validate it with the steps below.

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

Organize all database operations in context modules — **never call Repo from the web layer** (LiveViews, controllers).

```elixir
defmodule MyApp.Media do
  alias MyApp.Media.{Image, Folder}
  alias MyApp.Repo

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
end
```

All standard CRUD functions (`list_*`, `get_*!`, `delete_*`) follow the same pattern. Controllers and LiveViews call context functions only — never `Repo` directly.

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | ecto-essentials | ecto-changeset-patterns |
| elixir-essentials | ecto-essentials | testing-essentials |
