---
name: mix-tasks-generators
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY when creating custom Mix tasks or using Phoenix generators. Invoke before defining
  custom Mix task modules with argument parsing and subcommands, scaffolding resources with
  phx.gen.live or phx.gen.context, generating authentication systems with phx.gen.auth,
  configuring dependencies and aliases in mix.exs, or writing tests for custom tasks.
  Covers Mix.Tasks module creation, generator patterns, and Mix project configuration.
  Trigger words: Mix task, custom task, phx.gen, generators, mix.exs, project configuration,
  phx.gen.live, phx.gen.auth, scaffold, seed data, ecto.setup, mix help, Mix.Project,
  OptionParser, @shortdoc, preferred_cli_env, alias, mix run, generator, phx.gen.html,
  phx.gen.context, phx.gen.json, phx.gen.channel.
---

# Mix Tasks & Generators

## RULES — Follow these with no exceptions

1. **Always call `Mix.Task.run("app.start")` first** — tasks that access the database or Repo need the app started
2. **Create custom tasks for project-specific workflows** — don't override standard Mix tasks
3. **Register `preferred_cli_env` in mix.exs** — set environment for custom tasks (dev/test/prod)
4. **Use transactions for data modifications** — wrap `Repo.insert_all`, `Repo.delete_all` in `Repo.transaction()`
5. **Test custom tasks with `Mix.Project.in_project/4`** — ensure tasks work correctly in isolation
6. **Follow `Mix.Tasks.Namespace.TaskName` naming** — file path must match: `lib/mix/tasks/namespace.task_name.ex`


## End-to-End Workflow

Follow this sequence when creating a custom Mix task:

1. **Create file** — create `lib/mix/tasks/<namespace>.<task_name>.ex`
2. **Define module** — use `defmodule Mix.Tasks.MyApp.TaskName do use Mix.Task`
3. **Add `@shortdoc`** — one-line description for `mix help`
4. **Implement `run/1`** — parse args with `OptionParser.parse/2` if needed
5. **Start app** — call `Mix.Task.run("app.start")` if using Repo
6. **Implement logic** — use transactions for data modifications
7. **Add to mix.exs** — register `preferred_cli_env` if needed
8. **Test** — use `Mix.Project.in_project/4` test helper
9. **Verify** — run `mix help | grep task_name` to confirm registration


## Phoenix Generators

```bash
# JSON context and schema (full CRUD with tests)
mix phx.gen.json Accounts User users email:string name:string --web API

# LiveView CRUD with Enum field
mix phx.gen.live Blog Post posts title:string body:text status:enum:draft:published:archived

# LiveView for existing table
mix phx.gen.live Blog Post posts --table existing_posts

# Context (logic layer only)
mix phx.gen.context Accounts User users email:string password_hash:string

# Channel
mix phx.gen.channel Room

# HTML (no LiveView)
mix phx.gen.html Blog Post posts title:string body:text

# Authentication system (accounts context, user schema, session plumbing)
mix phx.gen.auth Accounts User users --web Admin

# Context with existing schema
mix phx.gen.context Blog Post posts --table posts --app MyApp
```


## Custom Mix Tasks

### Basic Task with Transaction Safety

```elixir
# lib/mix/tasks/my_app.seed_data.ex
defmodule Mix.Tasks.MyApp.SeedData do
  use Mix.Task

  @shortdoc "Seeds the database with sample data"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case MyApp.Repo.transaction(fn -> MyApp.Seeds.run() end) do
      {:ok, _} ->
        count = MyApp.Repo.aggregate(MyApp.User, :count)
        Mix.shell().info("Data seeded successfully! (#{count} users in DB)")

      {:error, reason} ->
        Mix.shell().error("Seeding failed, transaction rolled back: #{inspect(reason)}")
        Mix.raise("Seed failed")
    end
  end
end
```

### Task with Arguments and Validation

> Demonstrates `OptionParser` with required flags, error reporting, dry-run support, and before/after count verification.

```elixir
defmodule Mix.Tasks.MyApp.ImportUsers do
  use Mix.Task

  @shortdoc "Imports users from a CSV file"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, errors} =
      OptionParser.parse(args,
        strict: [file: :string, dry_run: :boolean],
        aliases: [f: :file, d: :dry_run]
      )

    if Keyword.get(opts, :file) == nil do
      Mix.shell().error("Missing required --file argument")
      Mix.shell().info("\nUsage: mix my_app.import_users --file <path>")
      Mix.raise("Invalid arguments")
    end

    if errors != [] do
      Enum.each(errors, fn {key, value} -> Mix.shell().error("Unknown option: #{key} #{value}") end)
      Mix.raise("Invalid arguments")
    end

    Mix.Task.run("app.start")

    file = Keyword.get(opts, :file)
    dry_run? = Keyword.get(opts, :dry_run, false)
    if dry_run?, do: Mix.shell().info("Dry run mode - no changes will be made")

    before_count = MyApp.Repo.aggregate(MyApp.User, :count)

    case MyApp.Repo.transaction(fn ->
           MyApp.UserImporter.import_from_csv(file, dry_run: dry_run?)
         end) do
      {:ok, {:ok, count}} ->
        after_count = MyApp.Repo.aggregate(MyApp.User, :count)
        Mix.shell().info("Imported #{count} users (total: #{after_count}, was: #{before_count})")

      {:ok, {:error, reason}} ->
        Mix.shell().error("Import validation failed: #{reason}")
        Mix.raise("Import failed")

      {:error, reason} ->
        Mix.shell().error("Import failed, transaction rolled back: #{inspect(reason)}")
        Mix.raise("Import failed")
    end
  end
end

# Usage: mix my_app.import_users --file=users.csv --dry-run
```

### Task with Subcommands

```elixir
defmodule Mix.Tasks.MyApp.Migrate do
  use Mix.Task

  @shortdoc "Runs database migrations"

  @impl Mix.Task
  def run(["up"]),     do: Mix.Task.run("ecto.migrate")
  def run(["down"]),   do: Mix.Task.run("ecto.rollback")
  def run(["status"]), do: Mix.Task.run("ecto.migrations")
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


## Custom Generators

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

    def call(params) do
      {:ok, params}
    end
  end
  """)
end

# Usage: mix my_app.gen.service send_email
# Creates: lib/my_app/services/send_email.ex
```


## Mix Project Configuration

### Aliases

```elixir
# mix.exs
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

### Registering Custom Tasks

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.15",
    start_permanent: Mix.env() == :prod,
    deps: deps(),
    aliases: aliases(),
    preferred_cli_env: [
      "my_app.seed_data": :dev,
      "my_app.import_users": :dev
    ]
  ]
end
```


## Testing Custom Tasks

```elixir
defmodule Mix.Tasks.MyApp.SeedDataTest do
  use ExUnit.Case

  setup do
    MyApp.Repo.delete_all(MyApp.User)
    :ok
  end

  test "seeds data successfully" do
    Mix.Project.in_project(:my_app, ".", fn _ ->
      Mix.Tasks.MyApp.SeedData.run([])
      assert MyApp.Repo.aggregate(MyApp.User, :count) > 0
    end)
  end

  test "seeds expected count" do
    Mix.Project.in_project(:my_app, ".", fn _ ->
      Mix.Tasks.MyApp.SeedData.run([])
      assert MyApp.Repo.aggregate(MyApp.User, :count) == 10
    end)
  end
end
```


## Common Task Patterns

| Pattern | Key Steps |
|---|---|
| **Database Reset** (`my_app.reset`) | Chain `ecto.drop` → `ecto.create` → `ecto.migrate` → seed via `Mix.Task.run/1` |
| **Health Check** (`my_app.health_check`) | `app.start` → run named checks (DB, cache, HTTP) → report pass/fail → `Mix.raise/1` on any failure |
| **Cleanup** (`my_app.cleanup`) | Parse `--dry-run` flag → query expired records → report count → conditionally `Repo.delete_all/1` |

All follow the same skeleton: parse opts → `app.start` → transact → report.
