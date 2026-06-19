---
name: otp-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL OTP work. Invoke before writing GenServer, Supervisor, Task, or Agent modules.
  Covers GenServer public API patterns, fast init with handle_continue, call vs cast, handle_info,
  supervision strategies, DynamicSupervisor, Tasks, Agent, Registry, ETS, and process linking.
  Trigger words: GenServer, Supervisor, OTP, Task, Agent, Registry, ETS, process, supervision.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# OTP Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY GenServer, Supervisor, Task, or Agent module.

## RULES — Follow these with no exceptions

1. **Always use `@impl true`** before GenServer/Agent callbacks (init, handle_call, handle_cast, handle_info, terminate)
2. **Keep `init/1` fast** — no blocking calls, no DB queries; use `handle_continue` for expensive setup
3. **Use `GenServer.call` for request/response, `GenServer.cast` for fire-and-forget** — never cast when you need a result
4. **Always define a public API wrapping GenServer calls** — callers should never use `GenServer.call(pid, ...)` directly
5. **Use `Task.async`/`Task.await` with bounded timeouts** — never `Task.async` without a corresponding `Task.await` or `Task.yield`
6. **Name processes via Registry, not atoms** — atom table is finite and never garbage collected
7. **Supervisors own process lifecycle** — never start unsupervised long-running processes
8. **Handle `:DOWN` messages** from monitored processes — don't let them go unhandled
9. **Use `Task.Supervisor`** for fire-and-forget supervised work
10. **Prefer ETS over a bottleneck GenServer** for shared read-heavy state — one GenServer serializes all access

---

## GenServer

### Public API Pattern

Always wrap GenServer calls behind a public module API. Callers should not know they're talking to a GenServer.

❌ **Bad — leaks GenServer implementation:**
```elixir
GenServer.call(MyApp.Cache, {:get, key})
```

✅ **Good — public API hides the GenServer:**
```elixir
defmodule MyApp.Cache do
  use GenServer

  # --- Public API ---

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get(key, server \\ __MODULE__) do
    GenServer.call(server, {:get, key})
  end

  def put(key, value, server \\ __MODULE__) do
    GenServer.cast(server, {:put, key, value})
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end
end
```

### Fast Init with handle_continue

Never block in `init/1`. Use `handle_continue` for expensive setup.

❌ **Bad — blocks the supervisor:**
```elixir
@impl true
def init(opts) do
  data = MyApp.Repo.all(MyApp.Item)  # Blocks!
  {:ok, %{items: data}}
end
```

✅ **Good — returns immediately:**
```elixir
@impl true
def init(opts) do
  {:ok, %{items: []}, {:continue, :load_data}}
end

@impl true
def handle_continue(:load_data, state) do
  data = MyApp.Repo.all(MyApp.Item)
  {:noreply, %{state | items: data}}
end
```

### call vs cast

```elixir
# call — synchronous, caller waits for reply (use for reads, queries)
def get_count(server \\ __MODULE__) do
  GenServer.call(server, :get_count)
end

@impl true
def handle_call(:get_count, _from, state) do
  {:reply, state.count, state}
end

# cast — asynchronous (use for writes, side effects)
def increment(server \\ __MODULE__) do
  GenServer.cast(server, :increment)
end

@impl true
def handle_cast(:increment, state) do
  {:noreply, %{state | count: state.count + 1}}
end
```

### handle_info

```elixir
@impl true
def init(_opts) do
  Process.send_after(self(), :tick, 1_000)
  {:ok, %{count: 0}}
end

@impl true
def handle_info(:tick, state) do
  Process.send_after(self(), :tick, 1_000)
  {:noreply, %{state | count: state.count + 1}}
end
```

---

## Supervisors

### Supervision Strategies

```elixir
# one_for_one — restart only the failed child (most common)
children = [
  {MyApp.Cache, []},
  {MyApp.Worker, []}
]
Supervisor.start_link(children, strategy: :one_for_one)

# one_for_all — restart ALL children when one fails
Supervisor.start_link(children, strategy: :one_for_all)

# rest_for_one — restart failed child and all children started AFTER it
Supervisor.start_link(children, strategy: :rest_for_one)
```

### Application Supervision Tree

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Phoenix.PubSub, name: MyApp.PubSub},
      MyApp.Cache,
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### DynamicSupervisor for Runtime Children

```elixir
defmodule MyApp.RoomSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_room(room_id) do
    spec = {MyApp.Room, room_id: room_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_room(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
```

### Supervision Tree Setup Workflow

When wiring up a new supervision tree, follow this sequence:

1. **Define children** — list in dependency order (dependencies first)
2. **Choose strategy** — `one_for_one` unless children are interdependent
3. **Add to `Application.start/2`** — or to a parent supervisor's child list
4. **Verify startup** — run `mix run --no-halt` or `iex -S mix` and confirm no crashes
5. **Inspect with Observer** — `:observer.start()` in IEx to view the live supervision tree
6. **Check child counts** — `Supervisor.count_children(MyApp.Supervisor)` confirms expected active/specs counts
7. **Test restart behavior** — `Process.exit(pid, :kill)` and confirm the supervisor restarts the child

```elixir
# Quick verification in IEx
iex> Supervisor.which_children(MyApp.Supervisor)
# [{MyApp.Cache, #PID<0.200.0>, :worker, [MyApp.Cache]}, ...]

iex> Supervisor.count_children(MyApp.Supervisor)
# %{active: 3, specs: 3, supervisors: 0, workers: 3}
```

---

## Tasks

### async/await for Concurrent Work

```elixir
# Parallel fetch with bounded timeout
task1 = Task.async(fn -> fetch_user_profile(user_id) end)
task2 = Task.async(fn -> fetch_user_posts(user_id) end)

profile = Task.await(task1, 5_000)
posts = Task.await(task2, 5_000)
```

### async_stream for Batch Processing

```elixir
user_ids
|> Task.async_stream(&fetch_user/1, max_concurrency: 4, timeout: 10_000)
|> Enum.map(fn {:ok, result} -> result end)
```

### Supervised Tasks

```elixir
# Add to your supervision tree
{Task.Supervisor, name: MyApp.TaskSupervisor}

# Start supervised tasks
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  send_welcome_email(user)
end)
```

---

## Agent

```elixir
defmodule MyApp.Counter do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, & &1)
  end

  def increment do
    Agent.update(__MODULE__, &(&1 + 1))
  end
end
```

---

## Process Naming

### Registry (preferred)

```elixir
# In application supervision tree
{Registry, keys: :unique, name: MyApp.Registry}

# In GenServer start_link
def start_link(room_id) do
  GenServer.start_link(__MODULE__, room_id,
    name: {:via, Registry, {MyApp.Registry, {:room, room_id}}}
  )
end

# Lookup
def get_room(room_id) do
  case Registry.lookup(MyApp.Registry, {:room, room_id}) do
    [{pid, _}] -> {:ok, pid}
    [] -> {:error, :not_found}
  end
end
```

---

## ETS for Shared Read-Heavy State

A GenServer owns the ETS table (ensuring cleanup on crash) while reads bypass it entirely.

```elixir
defmodule MyApp.EtsCache do
  use GenServer

  @table :my_app_cache

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Reads go directly to ETS — no GenServer roundtrip
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  # Writes go through the GenServer to serialize mutations
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    :ets.insert(@table, {key, value})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    :ets.delete(@table, key)
    {:reply, :ok, state}
  end
end
```

**Key ETS options:**
- `:set` — unique keys (default); `:bag` — duplicate keys allowed
- `:public` — any process can read/write; `:protected` — owner writes, all read
- `read_concurrency: true` — optimise for concurrent reads
- `write_concurrency: true` — optimise for concurrent writes (trades some read performance)

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| **elixir-essentials** | Before writing any `.ex` file |
| **testing-essentials** | Before writing OTP tests |
| **telemetry-essentials** | When adding observability to OTP processes |
| **oban-essentials** | When choosing between OTP and Oban for background work |
