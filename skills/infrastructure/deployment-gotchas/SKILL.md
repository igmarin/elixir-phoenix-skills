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

Use this skill before modifying ANY deployment or release configuration.

## RULES — Follow these with no exceptions

1. **Use `runtime.exs` for all secrets and URLs; never hardcode secrets — use `System.get_env!/1`** — see §1 & §5
2. **Run migrations via release commands (`bin/migrate`)** — see §2
3. **Set `PHX_HOST` and `PHX_SERVER=true`** — see §3
4. **Run `mix assets.deploy` before building the release** — see §4
5. **Add a `/health` endpoint that queries the database** — see §6
6. **Use `config :logger, level: :info` in production** — see §7
7. **Use Docker multi-stage builds** for Elixir releases — see §4

---

## End-to-End Deployment Workflow

```
1. Build image (mix assets.deploy → mix release → docker build)
2. Run migrations (bin/my_app eval "MyApp.Release.migrate()")
3. Start app (bin/my_app start)
4. Verify /health returns HTTP 200 and {"database": "connected"}
5. If health check fails → rollback: bin/my_app eval "MyApp.Release.rollback(MyApp.Repo, <version>)"
```

---

## 1. runtime.exs vs config.exs

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

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

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

Always use `System.get_env!/1` in `runtime.exs` so the app crashes on startup if a required secret is missing rather than silently misconfiguring.

✅ **Good — read from environment, crash on startup if missing:**
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

| ❌ Don't | ✅ Do |
|----------|-------|
| Read env vars in `config/prod.exs` (compiled) | Read them in `config/runtime.exs` (evaluated at boot) |
| `System.get_env("SECRET")` that returns `nil` silently | `System.get_env!("SECRET")` so the release crashes on startup |
| Run `mix ecto.migrate` against a release | Run `bin/my_app eval "MyApp.Release.migrate()"` |
| Forget `PHX_SERVER=true` and get no HTTP server | Set `server: true` / `PHX_SERVER=true` in runtime config |
| Build the release before `mix assets.deploy` | Run `mix assets.deploy` first, then `mix release` |
| Ship a `/health` that returns 200 without checking the DB | Query the database in the health endpoint |
| Leave `:debug` logging on in prod (leaks PII/params) | Use `config :logger, level: :info` in production |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| telemetry-essentials | deployment-gotchas | None (standalone) |
