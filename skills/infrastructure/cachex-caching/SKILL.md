---
name: cachex-caching
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when implementing caching in Elixir applications. Invoke before adding caching layers.
  Configures Cachex instances, implements cache-aside and get-or-set patterns, sets TTL policies,
  builds cache warmers, monitors cache statistics, and sets up distributed caching across nodes.
  Trigger words: Cachex, caching, cache, TTL, ETS, distributed cache, cache warmer.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Cachex Caching

## RULES — Follow these with no exceptions

1. **Set appropriate TTL for cached data** — don't cache indefinitely unless data is immutable
2. **Use cache warmers for expensive data** — pre-populate cache on startup
3. **Monitor cache hit rates** — use telemetry to track cache effectiveness

---

## End-to-End Workflow

Follow this sequence when adding caching to a feature:

1. **Add dependency** — add `{:cachex, "~> 3.6"}` to `mix.exs` and run `mix deps.get`
2. **Configure cache** — start a named Cachex instance in your application supervisor with appropriate limits and TTL
3. **Implement get-or-set** — wrap data-fetching calls with `Cachex.fetch/3` to atomically cache results
4. **Add invalidation** — call `Cachex.del/2` after mutating data; fall back to TTL expiry if deletion fails
5. **Verify with stats** — enable `stats: true`, call `Cachex.stats/1` after exercising the code, and confirm `hit_rate` is non-zero

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:cachex, "~> 3.6"}
  ]
end

# application.ex
def start(_type, _args) do
  children = [
    {Cachex, name: :my_cache, limit: 1000}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

---

## Basic Operations

```elixir
Cachex.put(:my_cache, "user:123", %{name: "John", age: 30})

case Cachex.get(:my_cache, "user:123") do
  {:ok, value} -> IO.inspect(value)
  {:ok, nil} -> IO.puts("Cache miss")
end

Cachex.put(:my_cache, "session:abc", data, ttl: :timer.minutes(30))

Cachex.del(:my_cache, "user:123")

Cachex.clear(:my_cache)
```

---

## Get-or-Set Pattern

```elixir
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

---

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

---

## Cache Configuration

```elixir
children = [
  {Cachex,
   name: :my_cache,
   limit: 10_000,
   policy: Cachex.Policy.LRW,
   ttl: :timer.minutes(10),
   stats: true,
   hooks: [
     %Cachex.Hook{module: MyApp.CacheLogger}
   ]}
]
```

---

## Cache Invalidation

```elixir
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
    Cachex.fetch(:my_cache, "user:#{id}", fn _key ->
      user = Repo.get(User, id)
      {:commit, user, ttl: :timer.minutes(5)}
    end)
    |> elem(1)
  end
end
```

---

## Monitoring Cache Stats

```elixir
{Cachex, name: :my_cache, stats: true}

{:ok, stats} = Cachex.stats(:my_cache)

IO.inspect(stats)
# %{
#   hit_rate: 85.5,
#   hits: 8550,
#   misses: 1450,
#   gets: 10000,
#   sets: 1200,
#   evictions: 100
# }
```
