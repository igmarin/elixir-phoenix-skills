---
name: ash-framework
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY when considering, adopting, or working with Ash Framework for Elixir applications.
  Invoke before starting a new Ash project or major refactor. Guides defining Ash resources with
  attributes and relationships, configuring actions and policies, using Ash extensions (AshPostgres,
  AshPhoenix, AshJsonApi), and migrating from Phoenix contexts to Ash DSL patterns.
  Trigger words: Ash Framework, Ash resource, Ash action, resource-oriented, DSL, alternative to contexts,
  Ash domain, Ash policy, Ash extension, ash_postgres, ash_phoenix, Ash.JsonApi, AshQuery,
  AshChangeset, use Ash.Resource, use Ash.Domain.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Ash Framework

## RULES — Follow these with no exceptions

1. **Use `use Ash.Resource` for domain resources** — never manually implement protocols
2. **Define actions explicitly** — don't rely on `defaults [:read, :create]` without understanding what they expose
3. **Add policies for authorization** — every resource with sensitive data must have explicit policy blocks
4. **Use `Ash.Changeset.for_create/3` and `Ash.Changeset.for_update/3`** — not bare struct manipulation
5. **Run `mix ash_postgres.generate_migrations` before manual migration** — let Ash generate the schema
6. **Verify resource loads** — run `mix compile` and confirm no `Spark.Error.DslError` before proceeding

---

## End-to-End Workflow

Follow this sequence when starting a new Ash project:

1. **Add dependencies** — add `{:ash, "~> 3.0"}` and `{:ash_postgres, "~> 2.0"}` to `mix.exs`
2. **Configure Repo** — change `use Ecto.Repo` to `use AshPostgres.Repo, otp_app: :my_app`
3. **Define Domain module** — create a domain with `use Ash.Domain` and `resources do ... end`
4. **Define Resource** — use `use Ash.Resource, domain: MyApp.Domain, data_layer: AshPostgres.DataLayer`
5. **Configure postgres** — add `table` and `repo` in the `postgres do` block
6. **Define attributes** — use `uuid_primary_key`, `attribute`, `timestamps()` in the `attributes do` block
7. **Define relationships** — use `belongs_to`, `has_many`, `many_to_many` in `relationships do` block
8. **Define actions** — use `actions do` with `defaults`, `create`, `update`, `read` blocks
9. **Add policies** — use `policies do` block with `authorize_if` or `forbid_if` rules
10. **Generate migrations** — run `mix ash_postgres.generate_migrations` then `mix ash_postgres.migrate`
11. **Test with Ash API** — use `Domain.create!(resource, attributes)` to verify the resource works

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

Define attributes, then define relationships and actions incrementally. See [Resource Definition](#resource-definition) below.

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

Add `{:ash_phoenix, "~> 2.0"}` to deps. `AshPhoenix.Form` bridges Ash changesets to Phoenix form components.

Key pattern — build an `AshPhoenix.Form`, convert with `to_form/1`, and handle submit:

```elixir
# mount
form =
  post
  |> Ash.Changeset.for_update(:update, %{})
  |> AshPhoenix.Form.for_update()
  |> to_form()

# handle_event "save"
case Blog.update(Ash.Changeset.for_update(post, :update, params)) do
  {:ok, post} -> {:noreply, put_flash(socket, :info, "Saved.") |> assign(post: post)}
  {:error, cs} -> {:noreply, assign(socket, form: cs |> AshPhoenix.Form.for_update() |> to_form())}
end
```

See the [AshPhoenix docs](https://hexdocs.pm/ash_phoenix) for full LiveView and form component examples.

---

### AshJsonApi Integration

Add `{:ash_json_api, "~> 1.0"}` to deps. Expose resources as a JSON:API endpoint by adding the extension and router plug:

```elixir
# In your resource
use Ash.Resource,
  domain: MyApp.Blog,
  data_layer: AshPostgres.DataLayer,
  extensions: [AshJsonApi.Resource]

json_api do
  type "post"

  routes do
    base "/posts"
    get :read
    index :published
    post :create
    patch :publish
  end
end
```

```elixir
# router.ex
scope "/api/json" do
  pipe_through :api
  forward "/", AshJsonApi.Router, domains: [MyApp.Blog]
end
```

See the [AshJsonApi docs](https://hexdocs.pm/ash_json_api) for pagination, includes, and error serialization.

---

## Calculations and Aggregates

```elixir
# Add a count aggregate to a resource
aggregates do
  count :comment_count, :comments
  count :published_comment_count, :comments do
    filter expr(status == :published)
  end
end

# Use in queries
MyApp.Blog.Post
|> Ash.Query.filter(comment_count > 0)
|> MyApp.Blog.read!()
```

---

## Custom Validations

```elixir
# Custom validation in create action
create :create do
  accept [:title, :body, :author_id]

  validate str_length(:title, min: 1, max: 255) do
    message "Title must be between 1 and 255 characters"
  end

  validate changing(:body) do
    if Map.get(attributes, :status) == :published do
      message "Published posts cannot have body changed"
    end
  end
end
```

---

## Not Found Handling

```elixir
# Use bang (!) version for raising not found
post = MyApp.Blog.Post |> Ash.get!(id)

# Use non-bang version for graceful handling
case MyApp.Blog.Post |> Ash.get(id) do
  {:ok, post} -> # handle found
  {:error, _} -> # handle not found
end
```

---

## Sorting and Filtering

```elixir
# Sort by multiple fields
MyApp.Blog.Post
|> Ash.Query.sort([inserted_at: :desc, title: :asc])
|> MyApp.Blog.read!()

# Filter with complex conditions
MyApp.Blog.Post
|> Ash.Query.filter(
  status == :published and
  author_id == ^current_user.id and
  inserted_at >= ^from_date
)
|> MyApp.Blog.read!()
```

---

## Pagination

```elixir
# Offset-based pagination
MyApp.Blog.Post
|> Ash.Query.page(offset: 0, limit: 20)
|> MyRequest.read!()

# Keyset pagination (cursor-based, more efficient)
MyApp.Blog.Post
|> Ash.Query.page(limit: 20, after: last_inserted_at)
|> MyApp.Blog.read!()
```

---

## Error Handling Patterns

```elixir
# Pattern matching on all outcomes
case MyApp.Blog.Post
     |> Ash.Changeset.for_create(params)
     |> MyApp.Blog.create() do
  {:ok, post} ->
    {:ok, post}

  {:error, %Ash.Error.InvalidInput{fields: fields}} ->
    {:error, :validation, fields}

  {:error, %Ash.Error.Forbidden{}} ->
    {:error, :unauthorized}

  {:error, error} ->
    Logger.error("Unexpected error: #{inspect(error)}")
    {:error, :internal_error}
end
```

---

## Migrations from Ecto to Ash

When migrating from Ecto contexts to Ash:

1. **Create Ash resource matching existing schema** — don't change the DB first
2. **Update context functions to delegate to Ash** — wrap existing Repo calls
3. **Add policies** — begin with open policy, then restrict
4. **Update callers gradually** — one resource at a time
5. **Delete old context** — only after all callers use Ash

```elixir
# Old Ecto approach
def get_post!(id), do: Repo.get!(Post, id)

# New Ash approach - keep same interface
def get_post!(id) do
  MyApp.Blog.Post
  |> Ash.get!(id)
end
```
