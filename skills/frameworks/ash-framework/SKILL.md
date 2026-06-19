---
name: ash-framework
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when considering Ash Framework for Elixir applications. Invoke before starting a new project
  or major refactor. Covers when to use Ash, core concepts (resources, actions, policies), and
  comparison with Phoenix contexts.
  Trigger words: Ash Framework, Ash resource, Ash action, resource-oriented, DSL, alternative to contexts.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Ash Framework

Ash Framework is a declarative data management framework for Elixir, providing a resource-oriented approach to building applications.

## RULES — Follow these with no exceptions

1. **Understand when to use Ash vs Phoenix contexts** — Ash excels at complex domains with many relationships and business rules
2. **Define resources declaratively** — use Ash DSL for attributes, actions, and relationships
3. **Use actions for all data operations** — create, read, update, destroy through actions
4. **Implement policies for authorization** — built-in policy system for fine-grained access control
5. **Leverage Ash extensions** — AshPostgres, AshPhoenix, AshJsonApi for integrations
6. **Don't use Ash for simple CRUD** — Phoenix contexts are simpler for basic apps
7. **Learn the Ash way** — don't try to write Phoenix contexts in Ash syntax

---

## When to Use Ash

✅ **Good candidates for Ash:**
- Complex domains with many relationships
- Applications with intricate business rules
- Projects needing fine-grained authorization
- Apps requiring multiple API formats (JSON, GraphQL)
- Teams comfortable with DSLs and abstractions

❌ **Not ideal for Ash:**
- Simple CRUD applications
- Small projects with straightforward data models
- Teams new to Elixir/Phoenix
- Projects with tight deadlines (learning curve)

---

## Core Concepts

### Resource Definition

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource,
    domain: MyApp.Blog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints [max_length: 255]
    end

    attribute :body, :string do
      allow_nil? false
    end

    attribute :status, :atom do
      constraints [one_of: [:draft, :published, :archived]]
      default :draft
    end

    timestamps()
  end

  relationships do
    belongs_to :author, MyApp.Accounts.User do
      allow_nil? false
    end

    has_many :comments, MyApp.Blog.Comment
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :body, :status, :author_id]
    end

    update :publish do
      accept []
      change set_attribute(:status, :published)
    end

    read :published do
      filter expr(status == :published)
    end
  end
end
```

---

### Domain Module

```elixir
defmodule MyApp.Blog do
  use Ash.Domain

  resources do
    resource MyApp.Blog.Post
    resource MyApp.Blog.Comment
  end
end
```

---

### Using Actions

```elixir
# Create a post
post =
  MyApp.Blog.Post
  |> Ash.Changeset.for_create(:create, %{
    title: "Hello World",
    body: "This is my first post",
    author_id: user.id
  })
  |> MyApp.Blog.create!()

# Read posts
posts =
  MyApp.Blog.Post
  |> Ash.Query.for_read(:published)
  |> Ash.Query.filter(author_id == ^user.id)
  |> MyApp.Blog.read!()

# Update post
post
|> Ash.Changeset.for_update(:publish)
|> MyApp.Blog.update!()
```

---

### Policies (Authorization)

```elixir
defmodule MyApp.Blog.Post do
  # ... attributes and actions ...

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:author)
      authorize_if expr(status == :published)
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action(:update) do
      authorize_if relates_to_actor_via(:author)
    end

    policy action(:destroy) do
      authorize_if relates_to_actor_via(:author)
    end
  end
end
```

---

## Ash Extensions

### AshPostgres

```elixir
# mix.exs
defp deps do
  [
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"}
  ]
end
```

### AshPhoenix (LiveView integration)

```elixir
defmodule MyAppWeb.PostLive.Form do
  use MyAppWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    post = MyApp.Blog.Post |> Ash.Query.filter(id == ^id) |> MyApp.Blog.read_one!()

    form =
      post
      |> Ash.Changeset.for_update(:update)
      |> to_form()

    {:ok, assign(socket, form: form, post: post)}
  end

  def handle_event("validate", %{"post" => params}, socket) do
    form =
      socket.assigns.post
      |> Ash.Changeset.for_update(:update, params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"post" => params}, socket) do
    case socket.assigns.post
         |> Ash.Changeset.for_update(:update, params)
         |> MyApp.Blog.update() do
      {:ok, post} ->
        {:noreply, push_navigate(socket, to: ~p"/posts/#{post}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
```

---

## Ash vs Phoenix Contexts

| Feature | Phoenix Contexts | Ash Framework |
|---------|------------------|---------------|
| Learning curve | Low | High |
| Boilerplate | Manual | Generated by DSL |
| Authorization | Manual (policy modules) | Built-in policies |
| Relationships | Manual preloading | Automatic loading |
| API generation | Manual | AshJsonApi, AshGraphql |
| Best for | Simple to medium complexity | Complex domains |
| Flexibility | High | Constrained by DSL |

---

## Common Pitfalls

❌ **Don't** use Ash for simple CRUD apps
❌ **Don't** try to write Phoenix contexts in Ash syntax
❌ **Don't** skip learning the Ash way — it's different
❌ **Don't** ignore the learning curve — budget time for it
❌ **Don't** use Ash without understanding resources and actions

✅ **Do** use Ash for complex domains
✅ **Do** learn the DSL and core concepts
✅ **Do** leverage built-in authorization
✅ **Do** use Ash extensions for integrations
✅ **Do** compare with Phoenix contexts before choosing

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **ecto-essentials** | Ash uses Ecto under the hood |
| **phoenix-liveview-essentials** | For AshPhoenix integration |
| **phoenix-authorization-patterns** | Compare with Ash policies |
