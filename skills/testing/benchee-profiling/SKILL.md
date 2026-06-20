---
name: benchee-profiling
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY when profiling and benchmarking Elixir code, or before optimizing performance-critical
  code. Sets up Benchee benchmarks, measures execution time, compares function implementations,
  generates profiling reports with :fprof and :eprof, and integrates benchmark regression checks
  into CI pipelines.
  Trigger words: Benchee, benchmark, profiling, performance, optimization, speed, comparison,
  benchee.run, benchee.measure, fprof, eprof, profile, ips, runtime, memory_time, warmup,
  batch_size, inputs, regression, baseline, performance comparison.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Benchee Profiling

Benchee is the standard benchmarking library for Elixir, providing accurate performance measurements.

## RULES — Follow these with no exceptions

1. **Benchmark in production-like conditions** — use `MIX_ENV=prod` for realistic results
2. **Compare alternatives** — always benchmark at least 2 approaches to justify optimization
3. **Document performance regressions** — track benchmark results over time in `bench/baseline.json` with a >10% threshold
4. **Profile before benchmarking** — use `:fprof` or `:eprof` to identify the actual bottleneck before writing benchmarks
5. **Use multiple inputs** — test with small, medium, and large inputs to catch size-dependent behavior
6. **Warm up before measuring** — run warmup phase to let JIT compilation settle
7. **Run sufficient time** — use `time: 10` (10 seconds) for reliable measurements, not the default 5

---

## Workflow

1. **Profile with `:fprof` or `:eprof`** — identify which function is the actual bottleneck; verify the output explicitly names the expected slow call site before proceeding
2. **Identify the bottleneck** — confirm the slow call site before writing any benchmarks; if the profile output is ambiguous, re-run with a larger workload to amplify signal
3. **Write a comparative Benchee benchmark** — implement at least 2 alternative approaches
4. **Validate improvement** — confirm the faster approach wins across input sizes using `inputs:`; if results are within noise (< 5% difference), run 3 additional times to rule out variance
5. **Save baseline** — write results to `bench/baseline.json` and check for regressions (>10% threshold); if a regression is detected, compare against the previous 3 baseline runs before raising an error to rule out noise

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:benchee, "~> 1.3", only: :dev}
  ]
end
```

---

## Basic Benchmark

```elixir
# bench/list_benchmark.exs
list = Enum.to_list(1..10_000)

Benchee.run(%{
  "Enum.map" => fn -> Enum.map(list, &(&1 * 2)) end,
  "for comprehension" => fn -> for i <- list, do: i * 2 end,
  ":lists.map (Erlang)" => fn -> :lists.map(fn x -> x * 2 end, list) end
})
```

```bash
# Run benchmark
MIX_ENV=prod mix run bench/list_benchmark.exs
```

---

## Benchmark Configuration

```elixir
list = Enum.to_list(1..10_000)

Benchee.run(
  %{
    "Enum.sort" => fn -> Enum.sort(list) end,
    "Enum.sort_by" => fn -> Enum.sort_by(list, & &1) end
  },
  time: 10,              # Run each scenario for 10 seconds
  warmup: 2,             # Warm up for 2 seconds
  memory_time: 2,        # Measure memory usage
  reduction_time: 2,     # Measure reductions
  inputs: %{
    "small list" => Enum.to_list(1..100),
    "medium list" => Enum.to_list(1..10_000),
    "large list" => Enum.to_list(1..100_000)
  },
  formatters: [
    {Benchee.Formatters.Console, comparison: true},
    {Benchee.Formatters.HTML, file: "output/benchmark.html"}
  ]
)
```

---

## Comparing Approaches

```elixir
defmodule StringOperations do
  def concat_loop(strings) do
    Enum.reduce(strings, "", fn s, acc -> acc <> s end)
  end

  def concat_join(strings) do
    Enum.join(strings)
  end

  def concat_comprehension(strings) do
    for s <- strings, into: "", do: s
  end
end

strings = for i <- 1..1000, do: "string_#{i}"

Benchee.run(%{
  "reduce" => fn -> StringOperations.concat_loop(strings) end,
  "join" => fn -> StringOperations.concat_join(strings) end,
  "comprehension" => fn -> StringOperations.concat_comprehension(strings) end
})
```

---

## Profiling with :fprof

```elixir
:fprof.trace(:start, file: 'trace.trace')
MyApp.SlowFunction.run()
:fprof.trace(:stop)

:fprof.profile(file: 'trace.trace')
:fprof.analyse(dest: 'analysis.txt')
```

---

## Profiling with :eprof

```elixir
:eprof.start()

:eprof.start_profiling([self()])
MyApp.SlowFunction.run()
:eprof.stop_profiling()

:eprof.analyze()
:eprof.stop()
```

---

## CI Integration

```yaml
# .github/workflows/benchmark.yml
name: Benchmark

on:
  push:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run benchmarks
        run: |
          mix deps.get
          MIX_ENV=prod mix run bench/suite.exs --output results.json

      - name: Store results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: results.json
```

### Regression Comparison Script

```elixir
# bench/compare_with_baseline.exs
baseline_file = "bench/baseline.json"

results =
  Benchee.run(
    %{
      "current" => fn -> MyApp.FastFunction.run() end
    },
    time: 5,
    formatters: [{Benchee.Formatters.Console, comparison: true}]
  )

if File.exists?(baseline_file) do
  baseline = File.read!(baseline_file) |> Jason.decode!()

  current_ips = results.scenarios |> hd() |> Map.get(:ips)
  baseline_ips = baseline["ips"]

  regression = (baseline_ips - current_ips) / baseline_ips * 100

  if regression > 10 do
    Mix.raise("Performance regression detected: #{regression}% slower")
  end
end

File.write!(baseline_file, Jason.encode!(%{ips: results.scenarios |> hd() |> Map.get(:ips)}))
```

---

## Benchmark Suite Organization

```
bench/
├── string_benchmark.exs      # String operations
├── list_benchmark.exs        # List operations
├── json_benchmark.exs        # JSON encoding/decoding
├── suite.exs                 # Run all benchmarks
└── baseline.json             # Baseline for regression detection
```

```elixir
# bench/suite.exs
Code.require_file("bench/string_benchmark.exs")
Code.require_file("bench/list_benchmark.exs")
Code.require_file("bench/json_benchmark.exs")
```

---

## Real-World Benchmark Patterns

### Database Query Benchmark

```elixir
# bench/ecto_benchmark.exs
alias MyApp.Repo
alias MyApp.Accounts.User

# Setup - ensure you have test data
users = Repo.all(User)

Benchee.run(
  %{
    "Repo.all (no filter)" => fn -> Repo.all(User) end,
    "Repo.all + Enum.filter" => fn ->
      users |> Enum.filter(&(&1.active)) |> Enum.take(100)
    end,
    "Repo.query with filter" => fn ->
      Repo.all(from u in User, where: u.active == true, limit: 100)
    end
  },
  time: 10,
  warmup: 2,
  inputs: %{
    "100 users" => Enum.take(users, 100),
    "1000 users" => Enum.take(users, 1000)
  }
)
```

### HTTP Request Benchmark

```elixir
# bench/http_benchmark.exs
url = "https://api.example.com/data"

Benchee.run(
  %{
    "Req.get!" => fn -> Req.get!(url) end,
    "HTTPoison.get!" => fn -> HTTPoison.get!(url) end,
    "Finch.build + Finch.run" => fn ->
      request = Finch.build(:get, url)
      Finch.run(request, MyApp.Finch)
    end
  },
  time: 10,
  warmup: 2
)
```

### JSON Encoding/Decoding Benchmark

```elixir
# bench/json_benchmark.exs
data = %{
  users: for i <- 1..1000 do
    %{id: i, name: "User #{i}", email: "user#{i}@example.com", active: true}
  end,
  metadata: %{created: DateTime.utc_now(), version: "1.0"}
}

json_string = Jason.encode!(data)

Benchee.run(
  %{
    "Jason.encode!" => fn -> Jason.encode!(data) end,
    "Jason.encode_to_iodata!" => fn -> Jason.encode_to_iodata!(data) end,
    "Poison.encode!" => fn -> Poison.encode!(data) end
  },
  %{
    "Jason.decode!" => fn -> Jason.decode!(json_string) end,
    "Poison.decode!" => fn -> Poison.decode!(json_string) end
  },
  time: 10,
  warmup: 2
)
```

---

## Statistical Analysis

```elixir
# Run multiple times to ensure statistical significance
runs = 3

Enum.map(1..runs, fn _ ->
  Benchee.run(%{
    "my_function" => fn -> MyApp.my_function() end
  }, time: 5, warmup: 1)
end)
|> Enum.flat_map(& &1.scenarios)
|> Enum.group_by(& &1.name)
|> Enum.map(fn {name, results} ->
  ips_values = Enum.map(results, & &1.ips)
  avg_ips = Enum.sum(ips_values) / length(ips_values)

  {name, %{
    avg_ips: avg_ips,
    std_dev: Statistics.stdev(ips_values),
    variance: Statistics.variance(ips_values)
  }}
end)
|> Enum.each(fn {name, stats} ->
  IO.puts("#{name}: #{stats.avg_ips} ips (±#{stats.std_dev})")
end)
```

---

## Memory Profiling

```elixir
Benchee.run(
  %{
    "String manipulation" => fn ->
      list = for i <- 1..1000, do: "item_#{i}"
      Enum.join(list, ",")
    end,
    "Binary manipulation" => fn ->
      list = for i <- 1..1000, do: <<("item_#{i}"::binary)>>
      IO.iodata_to_binary(Enum.intersperse(list, <<","::binary>>))
    end
  },
  memory_time: 5,
  reduction_time: 5
)
```

---

## Common Pitfalls

1. **Don't benchmark in dev mode** — `MIX_ENV=prod` for accurate results
2. **Don't use small input sizes** — amplify differences with realistic data
3. **Don't run once and trust** — run 3-5 times to rule out variance
4. **Don't benchmark I/O in the same run** — separate network/disk benchmarks
5. **Don't ignore warmup** — BEAM JIT needs time to optimize
6. **Don't compare apples to oranges** — ensure implementations do the same thing

---

## Interpreting Results

```
Name                  ips        average  deviation      median      99th %
--------------------------------------------------------------------------------
Enum.map            2.10e6      0.48μs    ±0.71%      0.47μs      0.51μs
for comprehension   1.85e6      0.54μs    ±2.32%      0.53μs      0.58μs
:lists.map          1.92e6      0.52μs    ±1.15%      0.51μs      0.55μs

Comparison:
Enum.map            2.10e6
for comprehension   1.85e6 - 11.72% slower
:lists.map          1.92e6 - 8.63% slower
```

**Key metrics:**
- **ips** — iterations per second (higher is better)
- **average** — mean execution time (lower is better)
- **deviation** — standard deviation (lower = more stable)
- **99th %** — 99th percentile (worst case performance)
