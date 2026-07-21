---
name: otp-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL OTP work. Invoke before writing GenServer, Supervisor, Task, or Agent
  modules. Processes are for concurrency, state, and isolation — not code organization.
  Keep callbacks thin; pure modules do the work (FCIS). Covers GenServer API, handle_continue,
  call vs cast, supervision, Task, Agent, Registry, ETS. Trigger words: GenServer, Supervisor,
  OTP, Task, Agent, Registry, ETS, process, supervision, thin callbacks.
metadata:
  version: "1.0.0"
  user-invocable: "true"
---

# OTP Essentials

Use before any GenServer, Supervisor, Task, Agent, Registry, or ETS work.

Processes **isolate and schedule work**. Modules organize code. Put business logic in pure modules; call them from thin callbacks.

Canonical FP bar: [`docs/fcis-engineering-rules.md`](../../../docs/fcis-engineering-rules.md).

## Quick Reference

| Concern | Do this |
|---------|---------|
| Process purpose | Concurrency / state / isolation — not module layout |
| Callbacks | Thin; pure modules compute |
| Startup I/O | `handle_continue`, not blocking `init/1` |
| Naming | Registry, not dynamic atoms |
| Batch tasks | Handle `async_stream` `{:exit, _}` |
| ETS | `:protected`; writes via owner |


## RULES — Follow these with no exceptions

1. **Processes are not modules** — never invent a GenServer just to “group functions”
2. **Thin callbacks** — `handle_call` / `handle_cast` / `handle_info` / `perform` only coordinate; pure code computes
3. **Fast `init/1`** — defer heavy work with `{:ok, state, {:continue, term}}`
4. **Public API module** — callers use `MyApp.Foo.do_thing/1`, never raw `GenServer.call/2`
5. **`@impl true`** on every callback
6. **Supervise everything long-lived** — no orphan processes
7. **Registry over dynamic atoms** for process names
8. **ETS**: owner process + `:protected` (or deliberate design); reads can bypass GenServer; writes serialized
9. **Handle `async_stream` exits** — match `{:ok, _}` and `{:exit, reason}`
10. **Let it crash** under a supervisor — avoid blanket `try/rescue` in callbacks

## Thin GenServer (FCIS)

❌ **Bad:** business logic inside the callback

```elixir
@impl true
def handle_call({:quote, items}, _from, state) do
  total =
    Enum.reduce(items, 0, fn item, acc ->
      if item.active, do: acc + item.price, else: acc
    end)

  {:reply, total, state}
end
```

✅ **Good:** pure module + thin callback

```elixir
defmodule MyApp.Pricing do
  def quote(items), do: Enum.reduce(items, 0, &(&1.price + &2))
end

defmodule MyApp.QuoteServer do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def quote(items), do: GenServer.call(__MODULE__, {:quote, items})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:quote, items}, _from, state) do
    {:reply, MyApp.Pricing.quote(items), state}
  end
end
```

## GenServer skeleton

```elixir
defmodule MyApp.Counter do
  use GenServer

  # --- Client API ---
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, 0, Keyword.put_new(opts, :name, __MODULE__))
  def value, do: GenServer.call(__MODULE__, :value)
  def increment, do: GenServer.cast(__MODULE__, :increment)

  # --- Server ---
  @impl true
  def init(count), do: {:ok, count}

  @impl true
  def handle_call(:value, _from, count), do: {:reply, count, count}

  @impl true
  def handle_cast(:increment, count), do: {:noreply, count + 1}
end
```

| Call style | When |
|------------|------|
| `call` | Need a reply or ordering with backpressure |
| `cast` | Fire-and-forget; client must not depend on completion |
| `handle_info` | Messages from monitors, timers, other processes |

## `handle_continue` for heavy startup

❌ **Bad:** block `init/1` with I/O

```elixir
@impl true
def init(opts) do
  {:ok, %{data: Loader.load!(opts)}}  # delays process start / supervision
end
```

✅ **Good:** continue after the process is up

```elixir
@impl true
def init(opts) do
  {:ok, %{opts: opts}, {:continue, :load}}
end

@impl true
def handle_continue(:load, state) do
  data = Loader.load!(state.opts)
  {:noreply, Map.put(state, :data, data)}
end
```

## Supervision

```elixir
children = [
  {Registry, keys: :unique, name: MyApp.Registry},
  MyApp.Repo,
  {MyApp.QuoteServer, []},
  {Task.Supervisor, name: MyApp.TaskSupervisor}
]

opts = [strategy: :one_for_one, name: MyApp.Supervisor]
Supervisor.start_link(children, opts)
```

Prefer `:one_for_one` unless children are tightly coupled (`:rest_for_one` / `:one_for_all` with care).

## Tasks

❌ **Bad:** ignore failures from `async_stream`

```elixir
user_ids
|> Task.async_stream(&fetch_user/1, max_concurrency: 4, timeout: 10_000)
|> Enum.map(fn {:ok, result} -> result end)
```

✅ **Good:** handle exits and timeouts

```elixir
user_ids
|> Task.async_stream(&fetch_user/1, max_concurrency: 4, timeout: 10_000, on_timeout: :kill_task)
|> Enum.reduce([], fn
  {:ok, result}, acc -> [result | acc]
  {:exit, reason}, acc ->
    require Logger
    Logger.warning("task failed: #{inspect(reason)}")
    acc
end)
|> Enum.reverse()
```

```elixir
# One-off async
task = Task.async(fn -> fetch_profile(user_id) end)
profile = Task.await(task, 5_000)

# Supervised fire-and-forget
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn -> send_email(user) end)
```

## Agent (simple state only)

```elixir
defmodule MyApp.Counter do
  use Agent
  def start_link(v \\ 0), do: Agent.start_link(fn -> v end, name: __MODULE__)
  def value, do: Agent.get(__MODULE__, & &1)
  def increment, do: Agent.update(__MODULE__, &(&1 + 1))
end
```

Use Agent for trivial state; use GenServer when you need timeouts, multi-message protocols, or clear OTP semantics.

## Registry

```elixir
# supervision tree
{Registry, keys: :unique, name: MyApp.Registry}

def start_link(room_id) do
  GenServer.start_link(__MODULE__, room_id,
    name: {:via, Registry, {MyApp.Registry, {:room, room_id}}}
  )
end

def get_room(room_id) do
  case Registry.lookup(MyApp.Registry, {:room, room_id}) do
    [{pid, _}] -> {:ok, pid}
    [] -> {:error, :not_found}
  end
end
```

## ETS (read-heavy shared state)

Owner GenServer creates a **`:protected`** named table; readers call `:ets` directly; writers go through the server.

```elixir
defmodule MyApp.EtsCache do
  use GenServer
  @table :my_app_cache

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def put(key, value), do: GenServer.call(__MODULE__, {:put, key, value})

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    :ets.insert(@table, {key, value})
    {:reply, :ok, state}
  end
end
```

## Common pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| GenServer per context “for architecture” | Plain modules; process only if you need concurrency/state |
| Fat `handle_call` with business rules | Pure module + one-line callback |
| Block in `init/1` | `handle_continue` |
| Dynamic atom process names | `Registry` |
| `:public` ETS writes from anywhere | `:protected` + owner writes |
| `async_stream` only matching `{:ok, _}` | Handle `{:exit, reason}` |
| Unsupervised long-running tasks | `Task.Supervisor` / app tree |

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | otp-essentials | telemetry-essentials |
| elixir-essentials | otp-essentials | oban-essentials |
| testing-essentials | otp-essentials | telemetry-essentials |
