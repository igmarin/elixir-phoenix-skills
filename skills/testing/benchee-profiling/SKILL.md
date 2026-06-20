---
name: benchee-profiling
type: atomic
tags: [atomic]
license: MIT
description: >
  Sets up Benchee benchmarks, measures execution time, compares function implementations, generates
  profiling reports with :fprof and :eprof, and integrates benchmark regression checks into CI pipelines.
  Use when profiling and benchmarking Elixir code, or before optimizing performance-critical code.
  Trigger words: Benchee, benchmark, profiling, performance, optimization, speed, comparison.
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
