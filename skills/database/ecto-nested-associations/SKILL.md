---
name: ecto-nested-associations
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL nested association and multi-table work. Invoke before writing cast_assoc,
  cast_embed, Ecto.Multi, or cascade operations. Covers nested creates, updates with on_replace,
  Ecto.Multi for unrelated tables, on_delete strategies, and FK indexes.
  Trigger words: cast_assoc, cast_embed, Ecto.Multi, nested, association, cascade, on_delete,
  on_replace, has_many, has_one, belongs_to, many_to_many, preload, nested_changeset,
  multi-table transaction, atomic create, atomic update.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Ecto Nested Associations

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY nested association or multi-table code.

## RULES — Follow these with no exceptions

1. **Use `cast_assoc/3` for has_many/has_one** — never manually insert children in a separate step
2. **Use `Ecto.Multi` for operations spanning multiple unrelated tables** — do NOT use `Ecto.Multi` for nested associations
3. **Set `on_delete` explicitly in migrations** — `:delete_all` for owned children, `:nothing` for independent entities
4. **Always create indexes on foreign key columns**
5. **Use `on_replace: :delete` in `cast_assoc` for list management** — allows removing items by omitting them
6. **Preload associations before updating them** — `cast_assoc` compares against currently loaded data
7. **Do NOT require foreign keys in child changesets** — `cast_assoc` sets them automatically
8. **Use `Repo.transaction/1` with `Ecto.Multi`** — wrap multi-table operations for atomicity

---

## End-to-End Workflow

Follow this sequence for ANY nested association or multi-table operation:

1. **Identify ownership** — determine if children are owned (cascade delete) or independent
2. **Define schema** — add `has_many`/`belongs_to` with appropriate `on_replace` strategy
3. **Create migration** — add FK column with `on_delete` and create index
4. **Define changesets** — child changeset does NOT require FK field; parent uses `cast_assoc`
5. **Implement context function** — use `Repo.insert`/`Repo.update` with parent changeset
6. **Handle results** — pattern-match on `{:ok, _}` and `{:error, changeset}`
7. **Write tests** — test create, update (including removal), and error cases

---

## cast_assoc for Nested Creates

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    has_many :comments, MyApp.Blog.Comment

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> cast_assoc(:comments, with: &MyApp.Blog.Comment.changeset/2)
  end
end

defmodule MyApp.Blog.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    belongs_to :post, MyApp.Blog.Post
    timestamps()
  end

  # Do NOT validate :post_id — cast_assoc sets it automatically
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end

# Usage — create post with comments in one operation
Blog.create_post(%{
  title: "My Post",
  comments: [
    %{body: "First comment"},
    %{body: "Second comment"}
  ]
})
```

### Handling cast_assoc Failures

Nested changeset errors are embedded inside the parent changeset. Pattern-match on both outcomes:

```elixir
case Repo.insert(Post.changeset(%Post{}, attrs)) do
  {:ok, post} ->
    {:ok, post}

  {:error, changeset} ->
    # Top-level errors on changeset.errors
    # Nested errors on changeset.changes[:comments] (list of changesets)
    {:error, changeset}
end
```

---

## cast_assoc for Updates with on_replace

```elixir
defmodule MyApp.Recipes.Recipe do
  schema "recipes" do
    field :name, :string
    has_many :ingredients, MyApp.Recipes.Ingredient, on_replace: :delete

    timestamps()
  end

  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:ingredients, with: &MyApp.Recipes.Ingredient.changeset/2)
  end
end

# Update — send the full list; omitted items are deleted
def update_recipe(recipe, attrs) do
  recipe
  |> Repo.preload(:ingredients)  # Must preload before cast_assoc
  |> Recipe.changeset(attrs)
  |> Repo.update()
end
```

---

## Ecto.Multi for Unrelated Tables

```elixir
def create_order_with_payment(order_attrs, payment_attrs) do
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:order, Order.changeset(%Order{}, order_attrs))
  |> Ecto.Multi.insert(:payment, fn %{order: order} ->
    Payment.changeset(%Payment{}, Map.put(payment_attrs, :order_id, order.id))
  end)
  |> Repo.transaction()
end
```

### Handling Ecto.Multi Results

Always pattern-match on both success and error tuples from `Repo.transaction/1`:

```elixir
case create_order_with_payment(order_attrs, payment_attrs) do
  {:ok, %{order: order, payment: payment}} ->
    {:ok, order}

  {:error, failed_operation, failed_changeset, _changes_so_far} ->
    Logger.error("Multi failed at #{failed_operation}: #{inspect(failed_changeset.errors)}")
    {:error, failed_changeset}
end
```

---

## on_delete Strategies

```elixir
defmodule MyApp.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :body, :text
      # Owned children — delete when parent is deleted
      add :post_id, references(:posts, on_delete: :delete_all)

      timestamps()
    end

    create index(:comments, [:post_id])
  end
end
```

### Verifying FK Indexes After Migration

Confirm FK indexes exist in psql with `\d comments`. Expect an entry such as `comments_post_id_index`. If missing, add it in a new migration:

```elixir
def change do
  create index(:comments, [:post_id])
end
```

---

## Many-to-Many Associations

```elixir
# Schema for many-to-many with join_through
schema "posts" do
  field :title, :string
  many_to_many :tags, MyApp.Blog.Tag, join_through: "post_tags"
  timestamps()
end

# Creating with tags (use put_assoc for many_to_many)
def create_post(attrs) do
  %Post{}
  |> Post.changeset(attrs)
  |> put_assoc(:tags, attrs["tags"])
  |> Repo.insert()
end

# changeset must use many_to_many/3 not cast_assoc
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title])
  |> validate_required([:title])
  |> many_to_many(:tags, Tag, on_replace: :delete)
end
```

---

## Nested Update with Partial Data

When updating a nested association with only some fields:

```elixir
def update_post(post, %{post: post_attrs, comments: comments_attrs}) do
  post
  |> Repo.preload(:comments)  # CRITICAL: preload before cast_assoc
  |> Post.changeset(%{post_attrs | comments: comments_attrs})
  |> Repo.update()
end

# In the parent changeset:
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> validate_required([:title])
  |> cast_assoc(:comments, with: &Comment.changeset/2)
end

# In the child changeset - allow partial updates:
def changeset(comment, attrs) do
  comment
  |> cast(attrs, [:body])
  |> validate_required([:body])
  # Don't require :id in the changeset - Ecto matches by ID internally
end
```

---

## Handling Empty Nested Associations

When user submits an empty list (intending to clear all children):

```elixir
def update_post(post, attrs) do
  # attrs contains comments: [] — empty list means "remove all"
  post
  |> Repo.preload(:comments)
  |> cast(attrs, [:title])
  |> validate_required([:title])
  |> cast_assoc(:comments, with: &Comment.changeset/2)
  |> Repo.update()
end

# If user clears all comments, the `on_replace: :delete` handles removal automatically
```
