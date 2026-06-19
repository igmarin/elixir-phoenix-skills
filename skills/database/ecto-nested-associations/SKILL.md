---
name: ecto-nested-associations
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL nested association and multi-table work. Invoke before writing cast_assoc,
  cast_embed, Ecto.Multi, or cascade operations. Covers nested creates, updates with on_replace,
  Ecto.Multi for unrelated tables, on_delete strategies, and FK indexes.
  Trigger words: cast_assoc, cast_embed, Ecto.Multi, nested, association, cascade, on_delete, on_replace.
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
2. **Use `Ecto.Multi` for operations spanning multiple unrelated tables** — Multi provides explicit rollback control
3. **Set `on_delete` explicitly in migrations** — `:delete_all` for owned children, `:nothing` for independent entities
4. **Always create indexes on foreign key columns** — missing FK indexes cause slow joins
5. **Use `on_replace: :delete` in `cast_assoc` for list management** — allows removing items by omitting them
6. **Preload associations before updating them** — `cast_assoc` compares against currently loaded data

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

  # Do NOT require :post_id — cast_assoc sets it automatically
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

### on_delete Options

| Option | Behavior | Use When |
|--------|----------|----------|
| `:nothing` | No action (FK constraint may prevent delete) | References to independent entities |
| `:delete_all` | Delete all children | Owned children (comments, items) |
| `:nilify_all` | Set FK to nil | Optional relationships |
| `:restrict` | Prevent parent deletion | Critical relationships |

---

## Common Pitfalls

❌ **Don't** manually insert children when using `cast_assoc`
❌ **Don't** forget to preload before updating with `cast_assoc`
❌ **Don't** require foreign keys in child changesets
❌ **Don't** forget FK indexes
❌ **Don't** use `Ecto.Multi` for nested associations — use `cast_assoc`

✅ **Do** use `cast_assoc` for has_many/has_one
✅ **Do** use `Ecto.Multi` for unrelated tables
✅ **Do** set `on_delete` explicitly
✅ **Do** use `on_replace: :delete` for list management
✅ **Do** preload associations before updating

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **ecto-essentials** | For schema and migration patterns |
| **ecto-changeset-patterns** | For changeset composition |
| **testing-essentials** | For testing nested associations |
