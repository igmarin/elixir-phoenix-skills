---
name: deployment-gotchas
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for deployment and release configuration. Invoke before modifying config/, rel/, or Dockerfile.
  Covers runtime.exs vs config.exs, release migrations, PHX_HOST/PHX_SERVER, asset deployment,
  secret management, health endpoints, and production log levels.
  Trigger words: deployment, release, runtime.exs, config, migration, PHX_HOST, Docker, health check, secrets.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Deployment Gotchas

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before modifying ANY deployment or release configuration.

## RULES — Follow these with no exceptions

1. **Use `runtime.exs` for secrets and URLs** — `config.exs`/`prod.exs` are compiled into the release and cannot read env vars at boot
2. **Run migrations via release commands (`bin/migrate`)** — `mix` is not available in production releases
3. **Set `PHX_HOST` and `PHX_SERVER=true`** — without these, URL generation breaks and the server won't start
4. **Run `mix assets.deploy` before building the release** — forgetting this means no CSS/JS in production
5. **Never hardcode secrets** — use `System.get_env!/1` in `runtime.exs` (the `!` crashes on boot if missing)
6. **Add a `/health` endpoint that queries the database** — load balancers need it, and a 200-only check hides DB failures
7. **Use `config :logger, level: :info` in production** — `:debug` logs query parameters including user data
8. **Use Docker multi-stage builds** for Elixir releases — separate build and runtime stages

---

## 1. runtime.exs vs config.exs

**The incident:** App deploys fine but uses the wrong database URL.

**Why:** `config.exs` and `prod.exs` are evaluated at **compile time**. `runtime.exs` is evaluated at **boot time**.

❌ **Bad — compiled into release, cannot read env vars at boot:**
```elixir
# config/prod.exs
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL")  # Always nil in release!
```

✅ **Good — evaluated at boot, reads env vars correctly:**
```elixir
# config/runtime.exs
if config_env() == :prod do
  database_url = System.get_env!("DATABASE_URL")

  config :my_app, MyApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
```

---

## 2. Release Migrations

**The incident:** Deploy succeeds but app crashes because new columns don't exist. `mix ecto.migrate` fails — `mix: command not found`.

✅ **Good — release module for migrations:**
```elixir
# lib/my_app/release.ex
defmodule MyApp.Release do
  @app :my_app

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
```

```bash
# Run migrations in production
bin/my_app eval "MyApp.Release.migrate()"
```

---

## 3. PHX_HOST and PHX_SERVER

✅ **Good:**
```elixir
# config/runtime.exs
if config_env() == :prod do
  host = System.get_env!("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :my_app, MyAppWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    server: true
end
```

---

## 4. Asset Deployment

✅ **Good — correct Dockerfile order:**
```dockerfile
# Multi-stage build
FROM elixir:1.16-alpine AS build

RUN apk add --no-cache build-base git
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

RUN mix assets.deploy
RUN mix release

# Runtime stage
FROM alpine:3.18 AS app
RUN apk add --no-cache libstdc++ openssl ncurses
WORKDIR /app

COPY --from=build /app/_build/prod/rel/my_app ./
ENV HOME=/app
CMD ["bin/my_app", "start"]
```

---

## 5. Never Hardcode Secrets

✅ **Good — read from environment, crash if missing:**
```elixir
# config/runtime.exs
if config_env() == :prod do
  secret_key_base = System.get_env!("SECRET_KEY_BASE")

  config :my_app, MyAppWeb.Endpoint,
    secret_key_base: secret_key_base
end
```

```bash
# Generate a secret
mix phx.gen.secret
```

---

## 6. Health Endpoints

✅ **Good — queries the database:**
```elixir
defmodule MyAppWeb.HealthController do
  use MyAppWeb, :controller

  def check(conn, _params) do
    case Ecto.Adapters.SQL.query(MyApp.Repo, "SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "ok", database: "connected"})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: inspect(reason)})
    end
  end
end
```

---

## 7. Production Log Level

✅ **Good:**
```elixir
# config/prod.exs
config :logger, level: :info

# config/runtime.exs — allow override for debugging
if config_env() == :prod do
  log_level =
    case System.get_env("LOG_LEVEL") do
      "debug" -> :debug
      "warning" -> :warning
      "error" -> :error
      _ -> :info
    end

  config :logger, level: log_level
end
```

---

## Common Pitfalls

❌ **Don't** put secrets in `config/prod.exs` — use `runtime.exs`
❌ **Don't** run `mix ecto.migrate` in production — use release commands
❌ **Don't** forget `PHX_HOST` and `PHX_SERVER=true`
❌ **Don't** skip `mix assets.deploy` before release
❌ **Don't** use a health endpoint that doesn't check the database
❌ **Don't** use `:debug` log level in production

✅ **Do** use `System.get_env!/1` for required env vars
✅ **Do** create a `Release` module for migrations
✅ **Do** use Docker multi-stage builds
✅ **Do** add a `/health` endpoint that queries the DB
✅ **Do** use `:info` log level in production

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **security-essentials** | When managing secrets and auditing dependencies |
| **telemetry-essentials** | When setting up production logging and metrics |
| **ecto-essentials** | When writing release migration modules |
| **phoenix-liveview-essentials** | When configuring endpoint for production |
