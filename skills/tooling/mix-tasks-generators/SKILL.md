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
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Mix Tasks & Generators

## RULES — Follow these with no exceptions

1. **Always call `Mix.Task.run("app.start")` first** — tasks that access the database or Repo need the app started
2. **Create custom tasks for project-specific workflows** — don't override standard Mix tasks
3. **Use `OptionParser.parse/2` for argument parsing** — never use raw `System.argv()` for complex arguments
4. **Add `@shortdoc` to every task** — tasks appear in `mix help` using this attribute
5. **Register `preferred_cli_env` in mix.exs** — set environment for custom tasks (dev/test/prod)
6. **Use transactions for data modifications** — wrap `Repo.insert_all`, `Repo.delete_all` in `Repo.transaction()`
7. **Test custom tasks with `Mix.Project.in_project/4`** — ensure tasks work correctly in isolation
8. **Follow `Mix.Tasks.Namespace.TaskName` naming** — file path must match: `lib/mix/tasks/namespace.task_name.ex`

---

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

---

## Phoenix Generators

### Complete Generator Reference

```bash
# Generate JSON context and schema (full CRUD with tests)
mix phx.gen.json Accounts User users email:string name:string --web API

# Generate LiveView CRUD with Enum field
mix phx.gen.live Blog Post posts title:string body:text status:enum:draft:published:archived

# Generate LiveView for existing table
mix phx.gen.live Blog Post posts --table existing_posts

# Generate context (logic layer)
mix phx.gen.context Accounts User users email:string password_hash:string

# Generate Channel
mix phx.gen.channel Room

# Generate HTML (no LiveView)
mix phx.gen.html Blog Post posts title:string body:text

# Generate authentication system
mix phx.gen.auth Accounts User users --web Admin

# Generate embedded schema
mix phx.gen.embedded Post do
  field :title, :string
  field :body, :string
end

# Generate context with existing schema
mix phx.gen.context Blog Post posts --table posts --app MyApp
```

### Enum Field Syntax

```bash
# Enum fields require special enum:value:syntax
mix phx.gen.live Blog Post posts status:enum:draft:published:archived
```

### Auth

```bash
# Generate authentication system (creates accounts context, user schema, and session plumbing)
mix phx.gen.auth Accounts User users
```

---

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

    before_count = MyApp.Repo.aggregate(MyApp.User, :count)

    case MyApp.Repo.transaction(fn ->
           MyApp.UserImporter.import_from_csv(file, dry_run: dry_run?)
         end) do
      {:ok, {:ok, count}} ->
        after_count = MyApp.Repo.aggregate(MyApp.User, :count)
        Mix.shell().info("Imported #{count} users (total in DB: #{after_count}, was: #{before_count})")

      {:ok, {:error, reason}} ->
        Mix.shell().error("Import validation failed: #{reason}")
        Mix.raise("Import failed")

      {:error, reason} ->
        Mix.shell().error("Import failed, transaction rolled back: #{inspect(reason)}")
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

  setup do
    # Ensure clean state before each test
    MyApp.Repo.delete_all(MyApp.User)
    :ok
  end

  test "seeds data successfully" do
    # Run in test environment
    Mix.Project.in_project(:my_app, ".", fn _ ->
      Mix.Tasks.MyApp.SeedData.run([])

      # Assert data was created
      assert MyApp.Repo.aggregate(MyApp.User, :count) > 0
    end)
  end

  test "seeds data with specific count" do
    Mix.Project.in_project(:my_app, ".", fn _ ->
      Mix.Tasks.MyApp.SeedData.run([])

      count = MyApp.Repo.aggregate(MyApp.User, :count)
      assert count == 10  # or whatever the seed creates
    end)
  end

  test "handles empty database" do
    Mix.Project.in_project(:my_app, ".", fn _ ->
      # Database already clean
      Mix.Tasks.MyApp.SeedData.run([])

      assert MyApp.Repo.aggregate(MyApp.User, :count) > 0
    end)
  end
end
```

---

## Error Handling Patterns

```elixir
defmodule Mix.Tasks.MyApp.ImportData do
  use Mix.Task

  @shortdoc "Imports data from CSV file"

  @impl Mix.Task
  def run(args) do
    {opts, positional, errors} = OptionParser.parse(args,
      strict: [file: :string, dry_run: :boolean],
      aliases: [f: :file, d: :dry_run]
    )

    # Handle missing required arguments
    if Keyword.get(opts, :file) == nil do
      Mix.shell().error("Missing required --file argument")
      Mix.shell().info("\nUsage: mix my_app.import_data --file <path>")
      Mix.raise("Invalid arguments")
    end

    # Handle unknown arguments
    if errors != [] do
      Enum.each(errors, fn {key, value} ->
        Mix.shell().error("Unknown option: #{key} #{value}")
      end)
      Mix.raise("Invalid arguments")
    end

    Mix.Task.run("app.start")

    # Main logic with proper error handling
    file = Keyword.get(opts, :file)

    case read_and_validate_file(file) do
      {:ok, data} ->
        process_data(data, opts)

      {:error, :file_not_found} ->
        Mix.shell().error("File not found: #{file}")
        Mix.raise("Import failed")

      {:error, :invalid_format} ->
        Mix.shell().error("Invalid file format: #{file}")
        Mix.raise("Import failed")
    end
  end

  defp read_and_validate_file(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> parse_content(content)
        {:error, _} -> {:error, :read_failed}
      end
    else
      {:error, :file_not_found}
    end
  end

  defp parse_content(content) do
    # Parse and return data
    {:ok, []}
  end

  defp process_data(data, opts) do
    if Keyword.get(opts, :dry_run) do
      Mix.shell().info("Would import #{length(data)} records (dry run)")
    else
      # Actual import
      Mix.shell().info("Imported #{length(data)} records")
    end
  end
end
```

---

## Common Task Patterns

### Database Reset Task

```elixir
defmodule Mix.Tasks.MyApp.Reset do
  use Mix.Task

  @shortdoc "Resets the database (drops, creates, migrates, seeds)"

  @impl Mix.Task
  def run(_) do
    Mix.Task.run("app.start")

    Mix.shell().info("Dropping database...")
    Mix.Task.run("ecto.drop")
    Mix.shell().info("Creating database...")
    Mix.Task.run("ecto.create")
    Mix.shell().info("Running migrations...")
    Mix.Task.run("ecto.migrate")
    Mix.shell().info("Seeding data...")
    Mix.Task.run("my_app.seed_data")

    Mix.shell().info("Reset complete!")
  end
end
```

### Health Check Task

```elixir
defmodule Mix.Tasks.MyApp.HealthCheck do
  use Mix.Task

  @shortdoc "Verifies application health (DB, cache, external services)"

  @impl Mix.Task
  def run(_) do
    Mix.Task.run("app.start")

    results = [
      {"Database", check_db()},
      {"Cache", check_cache()},
      {"External API", check_api()}
    ]

    Mix.shell().info("\nHealth Check Results:")
    Enum.each(results, fn {name, :ok} ->
      Mix.shell().info("  ✓ #{name}: OK")
    end)

    failures = Enum.filter(results, fn {_, status} -> status != :ok end)
    if failures != [] do
      Enum.each(failures, fn {name, reason} ->
        Mix.shell().error("  ✗ #{name}: #{reason}")
      end)
      Mix.raise("Health check failed")
    end
  end

  defp check_db do
    case MyApp.Repo.run_query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} -> reason
    end
  end

  defp check_cache do
    :ok = Cachex.put(:health_cache, "ping", "pong")
    case Cachex.get(:health_cache, "ping") do
      {:ok, "pong"} -> :ok
      _ -> "Cache not responding"
    end
  end

  defp check_api do
    case Req.get("https://api.example.com/health") do
      {:ok, %{status: 200}} -> :ok
      {:error, reason} -> reason
    end
  end
end
```

### Cleanup Task

```elixir
defmodule Mix.Tasks.MyApp.Cleanup do
  use Mix.Task

  @shortdoc "Cleans up old records (sessions, expired data, logs)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [dry_run: :boolean])

    Mix.Task.run("app.start")

    dry_run? = Keyword.get(opts, :dry_run, false)

    if dry_run? do
      Mix.shell().info("DRY RUN - No changes will be made")
    end

    expired_sessions = MyApp.Session
      |> where(inserted_at: < fragment("now() - interval '30 days'"))
      |> MyApp.Repo.all()

    Mix.shell().info("Found #{length(expired_sessions)} expired sessions")

    unless dry_run? do
      {count, _} = MyApp.Session
        |> where(inserted_at: < fragment("now() - interval '30 days'"))
        |> MyApp.Repo.delete_all()

      Mix.shell().info("Deleted #{count} expired sessions")
    end
  end
end
```

---

## Phoenix Generator Reference

```bash
# Generate a JSON API context and schema
mix phx.gen.json Accounts User users email:string name:string

# Generate LiveView CRUD for existing schema
mix phx.gen.live Blog Post posts title:string body:text --live

# Generate a channel
mix phx.gen.channel Room

# Generate embedded schema (for embedded types)
mix phx.gen.embedded Post do
  field :title, :string
  field :body, :string
end

# Generate context with JSON and web files
mix phx.gen.context Accounts User users email:string password_hash:string --web Admin

# Generate with existing table (skip migration)
mix phx.gen.live Blog Post posts --table posts --app MyApp
```

---

## Task Output Formatting

```elixir
# Use colored output
IO.puts(:cyan, "Starting task...")
IO.puts(:green, "✓ Success")
IO.puts(:red, "✗ Failed")

# Progress bars for long operations
Mix.shell().info("Processing records...")
records
|> Enum.with_index()
|> Enum.each(fn {record, index} ->
  process_record(record)
  if rem(index, 100) == 0 do
    Mix.shell().info("  Processed #{index + 1}/#{total} records")
  end
end)
```
