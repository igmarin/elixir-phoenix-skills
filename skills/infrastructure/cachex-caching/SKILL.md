---
name: cachex-caching
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when implementing caching in Elixir applications. Invoke before adding caching layers.
  Covers Cachex setup, cache patterns, TTL, warmers, and distributed caching.
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
4. **Handle cache misses gracefully** — always have a fallback to fetch fresh data
5. **Monitor cache hit rates** — use telemetry to track cache effectiveness
6. **Don't cache user-specific data without care** — consider cache key design
7. **Use `Cachex.fetch/3` for get-or-set patterns** — atomic cache operations

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

## Distributed Caching

```elixir
# For distributed caching across nodes
children = [
  {Cachex,
   name: :distributed_cache,
   # Use a distributed backend
   remote: MyApp.DistributedCache,
   # Or use Cachex's built-in distribution
   transactions: true}
]

# Cachex will automatically sync across nodes
Cachex.put(:distributed_cache, "key", "value")
```

---

## Cache Invalidation

```elixir
defmodule MyApp.Accounts do
  def update_user(user, attrs) do
    with {:ok, updated_user} <- Repo.update(User.changeset(user, attrs)) do
      # Invalidate cache
      Cachex.del(:my_cache, "user:#{user.id}")

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

# Get cache statistics
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
    # Log cache operations
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

## Cache Key Design

```elixir
# Good cache keys
"user:#{user.id}"                    # User by ID
"user:#{user.id}:profile"           # User profile
"posts:page:#{page}:per:#{per_page}" # Paginated posts
"search:#{query_hash}"              # Search results (hash query)

# Bad cache keys
user                                # Entire struct (changes frequently)
"posts"                             # Too broad (all posts)
"#{query}"                          # Unhashed query (too long)
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

---

## Common Pitfalls

❌ **Don't** cache indefinitely without TTL
❌ **Don't** forget to invalidate cache on updates
❌ **Don't** cache user-specific data without proper keys
❌ **Don't** ignore cache hit rates — monitor effectiveness
❌ **Don't** use ETS directly — use Cachex for features

✅ **Do** use Cachex for application-level caching
✅ **Do** set appropriate TTL for cached data
✅ **Do** use cache warmers for expensive data
✅ **Do** handle cache misses gracefully
✅ **Do** monitor cache statistics

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **telemetry-essentials** | For cache monitoring |
| **otp-essentials** | For understanding ETS and process-based caching |
| **benchee-profiling** | For measuring cache effectiveness |
