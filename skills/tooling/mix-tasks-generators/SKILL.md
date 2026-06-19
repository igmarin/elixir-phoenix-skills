---
name: mix-tasks-generators
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when creating custom Mix tasks or using Phoenix generators. Invoke before defining
  custom Mix task modules with argument parsing and subcommands, scaffolding resources with
  phx.gen.live or phx.gen.context, generating authentication systems with phx.gen.auth,
  configuring dependencies and aliases in mix.exs, or writing tests for custom tasks.
  Covers Mix.Tasks module creation, generator patterns, and Mix project configuration.
  Trigger words: Mix task, custom task, phx.gen, generators, mix.exs, project configuration,
  phx.gen.live, phx.gen.auth, scaffold, seed data, ecto.setup.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Mix Tasks & Generators

## Key Rules

1. **Use Phoenix generators for standard patterns** — `phx.gen.live`, `phx.gen.context`, etc.
2. **Create custom tasks for project-specific workflows** — don't repeat complex shell commands
3. **Follow Mix task naming conventions** — `Mix.Tasks.MyApp.TaskName`
4. **Don't override standard Mix tasks** — create new tasks instead
5. **Always call `Mix.Task.run("app.start")` in tasks that need the application started**

---

## Phoenix Generators

### LiveView CRUD

```bash
# Generate LiveView CRUD for a resource
mix phx.gen.live Blog Post posts title:string body:text status:enum:draft:published:archived
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
```

### Auth

```bash
# Generate authentication system
mix phx.gen.auth Accounts User users
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

### Custom Task Workflow

Follow these steps when creating and integrating a new custom Mix task:

1. **Create the file** at `lib/mix/tasks/<namespace>.<task_name>.ex`
2. **Implement `run/1`** with argument parsing via `OptionParser.parse/2` as needed
3. **Add `@shortdoc`** so the task appears in `mix help`
4. **Register `preferred_cli_env`** in `mix.exs` if the task targets a specific env (e.g., `:dev`)
5. **Verify registration** — run `mix help | grep my_app` to confirm the task is listed
6. **Write tests** using `Mix.Project.in_project/4` (see Testing section below)

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

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | mix-tasks-generators | phoenix-liveview-essentials |
| ecto-essentials | mix-tasks-generators | testing-essentials |
