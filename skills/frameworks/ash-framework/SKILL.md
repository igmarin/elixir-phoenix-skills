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

Start with attributes, then add relationships and actions incrementally. See [Resource Definition](#resource-definition) below.

### Step 5 — Generate and Run Migrations

```bash
mix ash_postgres.generate_migrations
mix ash_postgres.migrate
```

**Validation checkpoint:** Confirm all resources load cleanly:

```bash
mix compile --force 2>&1 | grep -E '(error|warning)'
```

Expected output: no lines printed.

**Common failures:**
- **Migration conflict on existing table** — open the generated file in `priv/repo/migrations/` and remove or rename the conflicting `create table` statement before re-running.
- **`Spark.Error.DslError` (unknown DSL option)** — check the path in the error (e.g., `MyApp.Blog.Post > attributes > attribute > :constraints`) to locate the offending block.

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

> Full policy reference: see `POLICIES.md`.

```elixir
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
```

**Debugging authorization failures:** If a call raises `Ash.Error.Forbidden`, enable policy breakdown logging:

```elixir
# config/dev.exs
config :ash, :policies, log_policy_breakdowns: :error
```

---

### AshPhoenix LiveView Integration

> Full LiveView reference: see `LIVEVIEW.md`.

Pattern: (1) load resource and build changeset in `mount/3`, (2) rebuild changeset on `"validate"` events, (3) call domain function on `"save"` and handle `{:ok, _}` / `{:error, _}`.

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
        {:noreply, socket |> put_flash(:info, "Post updated.") |> assign(post: post)}

      {:error, changeset} ->
        form = changeset |> AshPhoenix.Form.for_update() |> to_form()
        {:noreply, assign(socket, form: form)}
    end
  end
end
```
