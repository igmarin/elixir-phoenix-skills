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

Cachex is a powerful caching library for Elixir with support for TTL, distributed caching, and cache warmers.

## RULES — Follow these with no exceptions

1. **Use Cachex for application-level caching** — built on ETS with a rich feature set
2. **Set appropriate TTL for cached data** — don't cache indefinitely unless data is immutable
3. **Use cache warmers for expensive data** — pre-populate cache on startup
4. **Monitor cache hit rates** — use telemetry to track cache effectiveness
5. **Use `Cachex.fetch/3` for get-or-set patterns** — atomic cache operations

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
    # Start cache with configuration
    {Cachex, name: :my_cache, limit: 1000}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

---

## Basic Operations

```elixir
# Set a value
Cachex.put(:my_cache, "user:123", %{name: "John", age: 30})

# Get a value
case Cachex.get(:my_cache, "user:123") do
  {:ok, value} -> IO.inspect(value)
  {:ok, nil} -> IO.puts("Cache miss")
end

# Set with TTL (time to live)
Cachex.put(:my_cache, "session:abc", data, ttl: :timer.minutes(30))

# Delete a value
Cachex.del(:my_cache, "user:123")

# Clear all values
Cachex.clear(:my_cache)
```

---

## Get-or-Set Pattern

```elixir
# Fetch from cache or compute and cache
{status, value} =
  Cachex.fetch(:my_cache, "user:123", fn key ->
    # Cache miss - fetch from database
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
    # Pre-populate cache with expensive data
    users = MyApp.Accounts.list_active_users()

    actions =
      Enum.map(users, fn user ->
        {:put, "user:#{user.id}", user, ttl: :timer.hours(1)}
      end)

    {:ok, actions}
  end
end

# Configure cache with warmer
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
   # Maximum number of entries
   limit: 10_000,
   # Eviction policy
   policy: Cachex.Policy.LRW,
   # Default TTL
   ttl: :timer.minutes(10),
   # Enable statistics
   stats: true,
   # Hooks for monitoring
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
      # Invalidate cache — if deletion fails, log and continue;
      # stale data will expire via TTL rather than blocking the update
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
# Enable stats in cache configuration
{Cachex, name: :my_cache, stats: true}

# Get cache statistics — run this after exercising the cache to verify hit_rate > 0
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

### Telemetry Integration

```elixir
defmodule MyApp.CacheTelemetry do
  def attach do
    :telemetry.attach(
      "cachex-stats",
      [:cachex, :command, :stop],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:cachex, :command, :stop], measurements, metadata, _config) do
    Logger.info("Cache operation",
      command: metadata.command,
      key: metadata.key,
      duration: measurements.duration,
      hit: metadata.result == :ok
    )
  end
end
```

---

## Testing with Cachex

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true

  setup do
    # Clear cache before each test
    Cachex.clear(:my_cache)
    :ok
  end

  test "caches user after first fetch" do
    user = user_fixture()

    # First call - cache miss
    result1 = Accounts.get_user(user.id)

    # Second call - cache hit
    result2 = Accounts.get_user(user.id)

    assert result1 == result2

    # Verify cache was populated
    assert {:ok, ^user} = Cachex.get(:my_cache, "user:#{user.id}")
  end

  test "invalidates cache on update" do
    user = user_fixture(name: "John")

    # Populate cache
    Accounts.get_user(user.id)

    # Update user
    {:ok, updated} = Accounts.update_user(user, %{name: "Jane"})

    # Cache should be invalidated
    assert {:ok, nil} = Cachex.get(:my_cache, "user:#{user.id}")

    # Next fetch gets fresh data
    fetched = Accounts.get_user(user.id)
    assert fetched.name == "Jane"
  end
end
```
