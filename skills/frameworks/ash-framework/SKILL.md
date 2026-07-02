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
---

# Ash Framework

## RULES — Follow these with no exceptions

1. **Use `use Ash.Resource` for domain resources** — never manually implement protocols
2. **Define actions explicitly** — don't rely on `defaults [:read, :create]` without understanding what they expose
3. **Add policies for authorization** — every resource with sensitive data must have explicit policy blocks
4. **Use `Ash.Changeset.for_create/3` and `Ash.Changeset.for_update/3`** — not bare struct manipulation
5. **Run `mix ash_postgres.generate_migrations` before manual migration** — let Ash generate the schema
6. **Verify resource loads** — run `mix compile` and confirm no `Spark.Error.DslError` before proceeding


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


### AshPhoenix LiveView Integration

Add `{:ash_phoenix, "~> 2.0"}` to deps. See [AshPhoenix docs](https://hexdocs.pm/ash_phoenix) for full LiveView and form component examples.

```elixir
# Build form from changeset in mount
form =
  post
  |> Ash.Changeset.for_update(:update, %{})
  |> AshPhoenix.Form.for_update()
  |> to_form()

# Handle save event — reassign form on error
case Blog.update(Ash.Changeset.for_update(post, :update, params)) do
  {:ok, post}  -> {:noreply, put_flash(socket, :info, "Saved.") |> assign(post: post)}
  {:error, cs} -> {:noreply, assign(socket, form: cs |> AshPhoenix.Form.for_update() |> to_form())}
end
```


### AshJsonApi Integration

Add `{:ash_json_api, "~> 1.0"}` to deps. See [AshJsonApi docs](https://hexdocs.pm/ash_json_api) for pagination, includes, and error serialization.

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


## Calculations and Aggregates

```elixir
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


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Rely on `defaults [:read, :create]` without knowing what they expose | Define actions explicitly and `accept` only the intended attributes |
| Build filters with string interpolation (`"status == '#{s}'"`) | Use pinned expressions: `Ash.Query.filter(status == ^status)` |
| Alter the DB schema by hand before defining the resource | Define the resource first, then `mix ash_postgres.generate_migrations` |
| Skip policy blocks on resources with sensitive data | Add `policies do ... end` with explicit `authorize_if`/`forbid_if` |
| Manipulate structs directly for writes | Use `Ash.Changeset.for_create/3` and `Ash.Changeset.for_update/3` |
| Rescue a generic error and lose context | Match specific types: `Ash.Error.Forbidden`, `Ash.Error.Query.NotFound` |
| Offset-paginate large result sets | Use keyset pagination (`Ash.Query.page(after: ...)`) |

### Custom Validations — use the action layer, not DB constraints

```elixir
create :create do
  accept [:title, :body, :author_id]

  validate str_length(:title, min: 1, max: 255) do
    message "Title must be between 1 and 255 characters"
  end
end
```

For multi-field or conditional logic, implement a custom `Ash.Resource.Validation` module:

```elixir
defmodule MyApp.Validations.TitleNotBlank do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :title) do
      nil -> {:error, field: :title, message: "can't be blank"}
      ""  -> {:error, field: :title, message: "can't be blank"}
      _   -> :ok
    end
  end
end
```

### Filtering — use `^` for safe interpolation, never string interpolation

```elixir
# NEVER: Ash.Query.filter("status == '#{params["status"]}'"})  -- injection risk
MyApp.Blog.Post
|> Ash.Query.filter(status == ^status and author_id == ^current_user.id)
|> Ash.Query.sort([inserted_at: :desc])
```

### Not Found — match on `Ash.Error.Query.NotFound` explicitly

```elixir
case MyApp.Blog.Post |> Ash.get(id) do
  {:ok, post}                            -> {:ok, post}
  {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
  {:error, error}                        -> {:error, error}
end
```

### Error Handling — match Ash error types specifically

```elixir
case MyApp.Blog.Post
     |> Ash.Changeset.for_create(params)
     |> MyApp.Blog.create() do
  {:ok, post}                                      -> {:ok, post}
  {:error, %Ash.Error.InvalidInput{fields: fields}} -> {:error, :validation, fields}
  {:error, %Ash.Error.Forbidden{}}                 -> {:error, :unauthorized}
  {:error, %Ash.Error.Changeset{errors: errors}}   -> {:error, :invalid_changeset, errors}
  {:error, error} ->
    Logger.error("Unexpected error: #{inspect(error)}")
    {:error, :internal_error}
end
```

### Pagination — use keyset pagination for large result sets

```elixir
MyApp.Blog.Post
|> Ash.Query.page(limit: 20, after: last_inserted_at)
|> MyApp.Blog.read!()
```


## Migrations from Ecto to Ash

**Always create the Ash resource first, then let Ash generate migrations** — never alter the DB schema before defining the resource.

```elixir
# Step 1: Create Ash resource matching existing schema
defmodule MyApp.Blog.Post do
  use Ash.Resource, domain: MyApp.Blog, data_layer: AshPostgres.DataLayer
  postgres do
    table "posts"
    repo MyApp.Repo
  end
end

# Step 2: Generate and run migration
# mix ash_postgres.generate_migrations
# mix ash_postgres.migrate

# Step 3: Update context to delegate to Ash
def get_post!(id) do
  MyApp.Blog.Post |> Ash.get!(id)
end
```


## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | ash-framework | phoenix-json-api |
| ecto-essentials | ash-framework | phoenix-authorization-patterns |

**Companion skills:**
- [testing-essentials](../../testing/testing-essentials/SKILL.md) — test Ash actions and policies
- [phoenix-liveview-essentials](../../phoenix/phoenix-liveview-essentials/SKILL.md) — wire AshPhoenix forms into LiveView
