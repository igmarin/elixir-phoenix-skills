---
name: telemetry-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL telemetry, logging, and observability work. Invoke before writing telemetry
  handlers, Logger calls, or metrics code. Covers structured logging, :telemetry basics, Ecto events,
  Phoenix events, LiveDashboard, custom business metrics, and external tool integration.
  Trigger words: telemetry, logging, Logger, metrics, LiveDashboard, observability, structured logging.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Telemetry Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY telemetry, logging, or metrics code.

## RULES — Follow these with no exceptions

1. **Use structured logging (`Logger.info("action", key: value)`)** — never string interpolation in log messages
2. **Attach telemetry handlers in `Application.start/2`** — not in modules that may restart
3. **Use `Ecto.Repo` telemetry events for query monitoring** — Ecto already emits events
4. **Use `Phoenix.LiveDashboard` in dev/staging** — free observability with zero code
5. **Tag telemetry events with metadata (user_id, request_id)** — without correlation IDs, traces are useless
6. **Never log at `:debug` level in production** — it includes query parameters and PII

---

## Structured Logging

❌ **Bad — unsearchable:**
```elixir
Logger.info("User #{user.id} created order #{order.id} for $#{order.total}")
```

✅ **Good — searchable, parseable:**
```elixir
Logger.info("Order created", user_id: user.id, order_id: order.id, total: order.total)
```

### Logger Metadata

```elixir
# In a Plug
defmodule MyAppWeb.Plugs.RequestMetadata do
  import Plug.Conn

  def call(conn, _opts) do
    Logger.metadata(
      request_id: conn.assigns[:request_id] || Ecto.UUID.generate(),
      remote_ip: to_string(:inet.ntoa(conn.remote_ip))
    )
    conn
  end
end
```

---

## :telemetry Basics

```elixir
# Emit a custom event
:telemetry.execute(
  [:my_app, :orders, :created],     # event name
  %{count: 1, total_cents: 4999},    # measurements
  %{user_id: user.id, source: :web}  # metadata
)
```

### Attaching Handlers

✅ **Good — in application.ex:**
```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    MyApp.Telemetry.attach_handlers()

    children = [MyApp.Repo, MyAppWeb.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule MyApp.Telemetry do
  require Logger

  def attach_handlers do
    :telemetry.attach_many("my-app-handlers", [
      [:my_app, :orders, :created],
      [:my_app, :payments, :processed]
    ], &handle_event/4, nil)
  end

  def handle_event([:my_app, :orders, :created], measurements, metadata, _config) do
    Logger.info("Order created",
      total_cents: measurements.count,
      user_id: metadata.user_id
    )
  end
end
```

---

## Telemetry Spans

```elixir
def process_order(order) do
  :telemetry.span([:my_app, :orders, :process], %{order_id: order.id}, fn ->
    result = do_process(order)
    {result, %{order_id: order.id, status: :completed}}
  end)
end
```

---

## Monitoring Slow Queries

```elixir
def handle_slow_query(_event, measurements, metadata, %{threshold_ms: threshold}) do
  duration_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)

  if duration_ms > threshold do
    Logger.warning("Slow query",
      duration_ms: duration_ms,
      source: metadata.source,
      query: metadata.query
    )
  end
end
```

---

## LiveDashboard Setup

```elixir
# router.ex
import Phoenix.LiveDashboard.Router

scope "/" do
  pipe_through :browser

  live_dashboard "/dashboard",
    metrics: MyAppWeb.Telemetry,
    ecto_repos: [MyApp.Repo]
end
```

---

## Common Pitfalls

❌ **Don't** use string interpolation in log messages
❌ **Don't** attach telemetry handlers in GenServer init
❌ **Don't** log at `:debug` level in production
❌ **Don't** forget to tag events with metadata
❌ **Don't** manually instrument Ecto queries — use built-in events

✅ **Do** use structured logging with key-value pairs
✅ **Do** attach handlers in `Application.start/2`
✅ **Do** use `:info` level in production
✅ **Do** tag events with request_id and user_id
✅ **Do** use LiveDashboard for dev/staging observability

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **deployment-gotchas** | For production configuration |
| **security-essentials** | For sensitive data logging rules |
| **otp-essentials** | For process monitoring patterns |
| **benchee-profiling** | For performance profiling |
