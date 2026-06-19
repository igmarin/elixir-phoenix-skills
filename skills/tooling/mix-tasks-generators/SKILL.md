---
name: mix-tasks-generators
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when creating custom Mix tasks or using Phoenix generators. Invoke before writing custom
  Mix tasks or running phx.gen.* commands. Covers custom task creation, generator patterns,
  and Mix project configuration.
  Trigger words: Mix task, custom task, phx.gen, generators, mix.exs, project configuration.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Mix Tasks & Generators

Mix is Elixir's build tool, providing tasks for compilation, testing, and custom workflows.

## RULES — Follow these with no exceptions

1. **Use Phoenix generators for standard patterns** — `phx.gen.live`, `phx.gen.context`, etc.
2. **Create custom tasks for project-specific workflows** — don't repeat complex shell commands
3. **Follow Mix task naming conventions** — `Mix.Tasks.MyApp.TaskName`
4. **Document tasks with `@shortdoc`** — provide help text for `mix help`
5. **Use `Mix.Task` behavior** — implement `run/1` callback
6. **Test custom tasks** — use `Mix.Project.in_project/4` for testing
7. **Don't override standard Mix tasks** — create new tasks instead

---

## Phoenix Generators

### LiveView CRUD

```bash
# Generate LiveView CRUD for a resource
mix phx.gen.live Blog Post posts title:string body:text status:enum:draft:published:archived

# This creates:
# - Context: lib/my_app/blog.ex
# - Schema: lib/my_app/blog/post.ex
# - LiveView: lib/my_app_web/live/post_live/index.ex, show.ex, form.ex
# - Tests: test/my_app/blog_test.exs, test/my_app_web/live/post_live_test.exs
```

### Context and Schema

```bash
# Generate context and schema only (no web layer)
mix phx.gen.context Blog Post posts title:string body:text

# Generate schema only
mix phx.gen.schema Blog.Post posts title:string body:text
```

### JSON API

```bash
# Generate JSON API controllers
mix phx.gen.json Blog Post posts title:string body:text

# This creates:
# - Context: lib/my_app/blog.ex
# - Schema: lib/my_app/blog/post.ex
# - Controller: lib/my_app_web/controllers/post_controller.ex
# - View: lib/my_app_web/controllers/post_json.ex
```

### Auth

```bash
# Generate authentication system
mix phx.gen.auth Accounts User users

# This creates:
# - Migration: priv/repo/migrations/*_create_users_auth_tables.exs
# - Schema: lib/my_app/accounts/user.ex
# - Context: lib/my_app/accounts.ex
# - LiveViews: lib/my_app_web/live/user_*_live.ex
# - Plugs: lib/my_app_web/user_auth.ex
```

---

## Custom Mix Tasks

### Basic Task

```elixir
# lib/mix/tasks/my_app.seed_data.ex
defmodule Mix.Tasks.MyApp.SeedData do
  use Mix.Task

  @shortdoc "Seeds the database with sample data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    # Your seeding logic
    MyApp.Seeds.run()

    Mix.shell().info("Data seeded successfully!")
  end
end
```

### Task with Arguments

```elixir
defmodule Mix.Tasks.MyApp.ImportUsers do
  use Mix.Task

  @shortdoc "Imports users from a CSV file"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [file: :string, dry_run: :boolean]
      )

    Mix.Task.run("app.start")

    file = Keyword.get(opts, :file, "users.csv")
    dry_run? = Keyword.get(opts, :dry_run, false)

    if dry_run? do
      Mix.shell().info("Dry run mode - no changes will be made")
    end

    case MyApp.UserImporter.import_from_csv(file, dry_run: dry_run?) do
      {:ok, count} ->
        Mix.shell().info("Imported #{count} users")

      {:error, reason} ->
        Mix.shell().error("Import failed: #{reason}")
        Mix.raise("Import failed")
    end
  end
end

# Usage:
# mix my_app.import_users --file=users.csv --dry-run
```

### Task with Subcommands

```elixir
defmodule Mix.Tasks.MyApp.Migrate do
  use Mix.Task

  @shortdoc "Runs database migrations"

  @impl Mix.Task
  def run(["up"]) do
    Mix.Task.run("ecto.migrate")
  end

  def run(["down"]) do
    Mix.Task.run("ecto.rollback")
  end

  def run(["status"]) do
    Mix.Task.run("ecto.migrations")
  end

  def run(_) do
    Mix.shell().info("""
    Usage:
      mix my_app.migrate up      - Run migrations
      mix my_app.migrate down    - Rollback last migration
      mix my_app.migrate status  - Show migration status
    """)
  end
end
```

---

## Custom Generators

### Generator Task

```elixir
# lib/mix/tasks/my_app.gen.service.ex
defmodule Mix.Tasks.MyApp.Gen.Service do
  use Mix.Task
  use Mix.Generator

  @shortdoc "Generates a service module"

  @impl Mix.Task
  def run([name]) do
    module_name = Macro.camelize(name)
    file_path = "lib/my_app/services/#{name}.ex"

    create_file(file_path, service_template(module_name: module_name))

    Mix.shell().info("Created service: #{file_path}")
  end

  embed_template(:service, """
  defmodule MyApp.Services.<%= @module_name %> do
    @moduledoc \"\"\"
    Service module for <%= @module_name %> operations.
    \"\"\"

    @doc \"\"\"
    Performs the main operation.
    \"\"\"
    def call(params) do
      # Implementation here
      {:ok, params}
    end
  end
  """)
end

# Usage: mix my_app.gen.service send_email
# Creates: lib/my_app/services/send_email.ex
```

---

## Mix Project Configuration

### Aliases

```elixir
# mix.exs
def project do
  [
    app: :my_app,
    version: "0.1.0",
    aliases: aliases()
  ]
end

defp aliases do
  [
    setup: ["deps.get", "ecto.setup"],
    "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
    "ecto.reset": ["ecto.drop", "ecto.setup"],
    test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
    "assets.deploy": ["esbuild default --minify", "phx.digest"]
  ]
end
```

### Custom Tasks in mix.exs

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.15",
    start_permanent: Mix.env() == :prod,
    deps: deps(),
    # Register custom tasks
    preferred_cli_env: [
      "my_app.seed_data": :dev,
      "my_app.import_users": :dev
    ]
  ]
end
```

---

## Testing Custom Tasks

```elixir
defmodule Mix.Tasks.MyApp.SeedDataTest do
  use ExUnit.Case

  test "seeds data successfully" do
    # Run in test environment
    Mix.Project.in_project(:my_app, ".", fn _ ->
      Mix.Tasks.MyApp.SeedData.run([])

      # Assert data was created
      assert MyApp.Repo.aggregate(MyApp.User, :count) > 0
    end)
  end
end
```

---

## Common Pitfalls

❌ **Don't** forget to run `Mix.Task.run("app.start")` for tasks that need the app
❌ **Don't** override standard Mix tasks
❌ **Don't** skip `@shortdoc` documentation
❌ **Don't** hardcode paths — use Mix project functions
❌ **Don't** forget to test custom tasks

✅ **Do** use Phoenix generators for standard patterns
✅ **Do** create custom tasks for project workflows
✅ **Do** document tasks with `@shortdoc`
✅ **Do** use `Mix.shell()` for output
✅ **Do** test custom tasks

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **ecto-essentials** | For database-related tasks |
| **phoenix-liveview-essentials** | When using phx.gen.live |
| **testing-essentials** | For testing generators |
