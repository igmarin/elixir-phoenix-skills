---
name: cachex-caching
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for implementing caching in Elixir applications. Invoke before adding caching layers.
  Configures Cachex instances, implements cache-aside and get-or-set patterns, sets TTL policies,
  builds cache warmers, monitors cache statistics, and sets up distributed caching across nodes.
  Trigger words: Cachex, caching, cache, TTL, ETS, distributed cache, cache warmer, cache warmup,

  cache invalidation, cache hits, cache misses, Cachex.fetch, Cachex.put, Cachex.get.
---

# Cachex Caching

## RULES — Non-obvious requirements

1. **Set TTL on every cached entry** — never cache indefinitely unless data is truly immutable
2. **Enable stats: true** — required to measure cache effectiveness
3. **Use cache warmers for startup** — pre-populate expensive data when application starts


## End-to-End Workflow

Follow this sequence when adding caching to a feature:

1. **Add dependency** — add `{:cachex, "~> 3.6"}` to `mix.exs` and run `mix deps.get`
2. **Configure cache** — start a named Cachex instance in your application supervisor
3. **Implement get-or-set** — use `Cachex.fetch/3` for atomic cache-aside pattern
4. **Add invalidation** — call `Cachex.del/2` after mutating data
5. **Enable stats** — configure `stats: true` in cache options
6. **Add cache warmer** — for expensive data, pre-populate on startup
7. **Verify hit rate** — call `Cachex.stats/1` and confirm `hit_rate` is non-zero; see **Monitoring Cache Stats** for interpretation thresholds and remediation guidance
8. **Monitor in production** — emit telemetry events for cache operations


## Setup

```elixir
# mix.exs
defp deps do
  [
    {:cachex, "~> 3.6"}
  ]
end
```

**In your application supervisor:**

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Basic cache with 1000 entry limit
      {Cachex, name: :my_cache, limit: 1000},
      
      # Cache with stats enabled for monitoring
      {Cachex, name: :stats_cache, limit: 5000, stats: true},
      
      # Cache with TTL, LRW eviction policy, stats, and hooks
      {Cachex,
       name: :ttl_cache,
       limit: 10_000,
       ttl: :timer.minutes(10),
       policy: Cachex.Policy.LRW,
       stats: true,
       hooks: [
         %Cachex.Hook{module: MyApp.CacheLogger}
       ]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```


## Basic Operations

```elixir
case Cachex.get(:my_cache, "user:123") do
  {:ok, nil} -> :miss
  {:ok, value} -> {:hit, value}
end

# put with explicit TTL (overrides cache-level default)
Cachex.put(:my_cache, "session:abc", data, ttl: :timer.minutes(30))

Cachex.del(:my_cache, "user:123")
Cachex.clear(:my_cache)
```


## Get-or-Set Pattern

```elixir
# Cachex.fetch/3 — atomic cache-aside, avoids race conditions
{status, value} =
  Cachex.fetch(:my_cache, "user:123", fn key ->
    user = MyApp.Accounts.get_user(123)
    {:commit, user, ttl: :timer.minutes(5)}
  end)

case status do
  :ok -> IO.puts("Cache hit")
  :commit -> IO.puts("Cache miss - computed and cached")
end
```


## Cache Warmers

```elixir
defmodule MyApp.CacheWarmer do
  use Cachex.Warmer

  def execute(state) do
    users = MyApp.Accounts.list_active_users()

    actions =
      Enum.map(users, fn user ->
        {:put, "user:#{user.id}", user, ttl: :timer.hours(1)}
      end)

    {:ok, actions}
  end
end

children = [
  {Cachex,
   name: :my_cache,
   warmers: [
     %Cachex.Warmer{module: MyApp.CacheWarmer, interval: :timer.minutes(5)}
   ]}
]
```


## Cache Invalidation

```elixir
# All Cachex operations return {:ok, result} or {:error, reason}; fall back to DB on failure
defmodule MyApp.Accounts do
  def update_user(user, attrs) do
    with {:ok, updated_user} <- Repo.update(User.changeset(user, attrs)) do
      case Cachex.del(:my_cache, "user:#{user.id}") do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Cache invalidation failed for user:#{user.id}: #{inspect(reason)}")
      end

      {:ok, updated_user}
    end
  end

  def get_user(id) do
    case Cachex.fetch(:my_cache, "user:#{id}", fn _ ->
      {:commit, Repo.get(User, id), ttl: :timer.minutes(5)}
    end) do
      {:ok, user} -> user
      {:error, _} -> Repo.get(User, id)  # Fallback to database
    end
  end
end
```


## Monitoring Cache Stats

```elixir
{Cachex, name: :my_cache, stats: true}

{:ok, stats} = Cachex.stats(:my_cache)
# %{hit_rate: 85.5, hits: 8550, misses: 1450, gets: 10000, sets: 1200, evictions: 100}
```

**Interpret hit rate:**
- `> 80%` — excellent, cache is very effective
- `60-80%` — good, normal for read-heavy workloads
- `< 60%` — investigate TTL values and check for over-invalidation
- `< 20%` — cache may be ineffective; revisit TTL strategy and key design before deploying to production


## Telemetry Integration

Emit telemetry events for cache operations to monitor in production:

```elixir
def get_user(id) do
  case Cachex.fetch(:my_cache, "user:#{id}", fn _ ->
    {:commit, Repo.get(User, id)}
  end) do
    {:ok, user} ->
      :telemetry.execute([:my_app, :cache, :my_cache], %{hits: 1}, %{key: "user:#{id}"})
      user
    {:error, _} ->
      :telemetry.execute([:my_app, :cache, :my_cache], %{misses: 1}, %{key: "user:#{id}"})
      Repo.get(User, id)
  end
end
```


## Distributed Caching

**Broadcast-based invalidation across nodes:**

```elixir
defmodule MyApp.CacheSync do
  @topic "cache:invalidate"

  def broadcast_delete(key) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, @topic, {:invalidate, key})
  end

  def handle_info({:invalidate, key}, state) do
    Cachex.del(:my_cache, key)
    {:noreply, state}
  end
end

# Subscribe in your GenServer or LiveView
Phoenix.PubSub.subscribe(MyApp.PubSub, "cache:invalidate")
```

**Remote reads via RPC (single authoritative node pattern):**

```elixir
def get_user_distributed(id) do
  case Cachex.get(:my_cache, "user:#{id}") do
    {:ok, nil} ->
      :rpc.call(primary_node(), Cachex, :get, [:my_cache, "user:#{id}"])
      |> case do
        {:ok, nil} -> fetch_from_db(id)
        {:ok, value} -> value
      end

    {:ok, value} ->
      value
  end
end

defp primary_node, do: Application.fetch_env!(:my_app, :primary_cache_node)
```
