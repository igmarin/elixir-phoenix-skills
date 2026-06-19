---
name: ash-framework
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when considering, adopting, or working with Ash Framework for Elixir applications. Invoke
  before starting a new project or major refactor. Guides defining Ash resources with attributes
  and relationships, configuring actions and policies, using Ash extensions (AshPostgres,
  AshPhoenix, AshJsonApi), and migrating from Phoenix contexts to Ash DSL patterns.
  Trigger words: Ash Framework, Ash resource, Ash action, resource-oriented, DSL, alternative to contexts.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Ash Framework

Ash Framework is a declarative data management framework for Elixir, providing a resource-oriented approach to building applications.

---

## Decision Guide — When to Use Ash

✅ **Good candidates for Ash:**
- Complex domains with many relationships and intricate business rules
- Projects needing fine-grained authorization
- Apps requiring multiple API formats (JSON, GraphQL)
- Teams comfortable with DSLs and abstractions

❌ **Not ideal for Ash:**
- Simple CRUD applications or small projects with straightforward data models
- Teams new to Elixir/Phoenix or projects with tight deadlines (learning curve is significant)
- Contexts where Phoenix's manual flexibility is more appropriate

**Key principles:**
- Use Ash's declarative patterns instead of imperative Phoenix context code
- Use AshPostgres, AshPhoenix, or AshJsonApi rather than reimplementing integrations
- Plan for a significant learning curve; the DSL differs materially from plain Ecto/Phoenix

---

## Setup Workflow

Follow this sequence when starting a new Ash project:

### Step 1 — Add Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"}
  ]
end
```

Run `mix deps.get`.

### Step 2 — Configure AshPostgres

Use `AshPostgres.Repo` in your Repo module and add the repo to `config/config.exs`:

```elixir
defmodule MyApp.Repo do
  use AshPostgres.Repo, otp_app: :my_app
end
```

### Step 3 — Define a Domain Module

```elixir
defmodule MyApp.Blog do
  use Ash.Domain

  resources do
    resource MyApp.Blog.Post
    resource MyApp.Blog.Comment
  end
end
```

### Step 4 — Define Your First Resource

Start with attributes, then add relationships and actions incrementally. Use the [Resource Definition](#resource-definition) section below for a full example.

### Step 5 — Generate and Run Migrations

```bash
mix ash_postgres.generate_migrations
mix ash_postgres.migrate
```

**Validation checkpoint:** Compile the project and confirm all resources load cleanly:

```bash
mix compile --force 2>&1 | grep -E '(error|warning)'
```

Expected output: no lines printed. If you see compilation errors, check that every resource listed in the domain module exists and that the `data_layer` option is set correctly.

**Common migration failure — conflict on existing table:** If `ash_postgres.generate_migrations` errors with a conflict, check the generated migration file in `priv/repo/migrations/` and remove or rename the conflicting `create table` statement before re-running.

**Common compilation error — unknown DSL option:** Ash surfaces these as `** (Spark.Error.DslError)`. Check the path printed in the error (e.g., `MyApp.Blog.Post > attributes > attribute > :constraints`) to locate the offending block.

### Step 6 — Call Actions from Your Application

Use `Ash.Changeset` and domain functions (e.g., `MyApp.Blog.create!`) to interact with resources. See [Using Actions](#using-actions) below.

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

**Policy authorization failure:** If a call raises `Ash.Error.Forbidden`, the actor did not satisfy any `authorize_if` clause. Enable policy debugging to inspect which clause failed:

```elixir
# In config/dev.exs
config :ash, :policies, log_policy_breakdowns: :error
```

This logs a breakdown of each evaluated clause so you can identify which condition needs adjustment.

---

### AshPhoenix LiveView Integration

The pattern for integrating AshPhoenix with LiveView forms follows three steps:

1. Load the resource and build a changeset in `mount/3`
2. Re-build the changeset on `"validate"` events using `to_form/1`
3. Call the domain update/create function on `"save"` and handle `{:ok, _}` / `{:error, _}`

```elixir
defmodule MyAppWeb.PostLive.Edit do
  use MyAppWeb, :live_view

  alias MyApp.Blog
  alias MyApp.Blog.Post

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Blog.get!(Post, id)

    form =
      post
      |> Ash.Changeset.for_update(:update, %{})
      |> AshPhoenix.Form.for_update()
      |> to_form()

    {:ok, assign(socket, form: form, post: post)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.post
      |> Ash.Changeset.for_update(:update, params)
      |> AshPhoenix.Form.for_update()
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case socket.assigns.post
         |> Ash.Changeset.for_update(:update, params)
         |> Blog.update() do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post updated.")
         |> assign(post: post)}

      {:error, changeset} ->
        form = changeset |> AshPhoenix.Form.for_update() |> to_form()
        {:noreply, assign(socket, form: form)}
    end
  end
end
```

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| ecto-essentials | ash-framework | None (standalone) |
