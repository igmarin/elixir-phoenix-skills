---
name: benchee-profiling
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when profiling and benchmarking Elixir code. Invoke before optimizing performance-critical code.
  Covers Benchee setup, benchmark patterns, comparison, profiling, and CI integration.
  Trigger words: Benchee, benchmark, profiling, performance, optimization, speed, comparison.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Benchee Profiling

Benchee is the standard benchmarking library for Elixir, providing accurate performance measurements.

## RULES — Follow these with no exceptions

1. **Use Benchee for all benchmarking** — the standard library with statistical analysis
2. **Benchmark in production-like conditions** — use `MIX_ENV=prod` for realistic results
3. **Compare alternatives** — always benchmark at least 2 approaches to justify optimization
4. **Run benchmarks multiple times** — use `warmup` and `time` for statistical significance
5. **Profile before optimizing** — use `:fprof` or `:eprof` to find actual bottlenecks
6. **Document performance regressions** — track benchmark results over time
7. **Don't optimize prematurely** — measure first, optimize second

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
# bench/string_benchmark.exs
list = Enum.to_list(1..10_000)

Benchee.run(%{
  "Enum.map" => fn -> Enum.map(list, &(&1 * 2)) end,
  "for comprehension" => fn -> for i <- list, do: i * 2 end,
  "Enum.map with capture" => fn -> Enum.map(list, &(&1 * 2)) end
})
```

```bash
# Run benchmark
MIX_ENV=prod mix run bench/string_benchmark.exs
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
# Benchmark different implementations
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
# Profile a function call
:fprof.trace(:start, file: 'trace.trace')
MyApp.SlowFunction.run()
:fprof.trace(:stop)

# Analyze the trace
:fprof.profile(file: 'trace.trace')
:fprof.analyse(dest: 'analysis.txt')
```

---

## Profiling with :eprof

```elixir
# Start profiling
:eprof.start()

# Profile function calls
:eprof.start_profiling([self()])
MyApp.SlowFunction.run()
:eprof.stop_profiling()

# Show results
:eprof.analyze()

# Stop
:eprof.stop()
```

---

## Memory Profiling

```elixir
Benchee.run(
  %{
    "small struct" => fn -> %User{name: "John", age: 30} end,
    "large struct" => fn ->
      %{
        name: "John",
        age: 30,
        email: "john@example.com",
        address: "123 Main St",
        phone: "555-1234"
      }
    end
  },
  memory_time: 5,
  reduction_time: 5
)
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

### Benchmark Comparison Script

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

# Compare with baseline
if File.exists?(baseline_file) do
  baseline = File.read!(baseline_file) |> Jason.decode!()

  # Check for regressions
  current_ips = results.scenarios |> hd() |> Map.get(:ips)
  baseline_ips = baseline["ips"]

  regression = (baseline_ips - current_ips) / baseline_ips * 100

  if regression > 10 do
    Mix.raise("Performance regression detected: #{regression}% slower")
  end
end

# Save current results as new baseline
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

## Common Pitfalls

❌ **Don't** benchmark in dev environment — use `MIX_ENV=prod`
❌ **Don't** skip warmup time — JIT compilation affects results
❌ **Don't** benchmark without comparison — you need a baseline
❌ **Don't** optimize without profiling — find actual bottlenecks
❌ **Don't** ignore statistical significance — run long enough

✅ **Do** use Benchee for all benchmarking
✅ **Do** benchmark in production-like conditions
✅ **Do** compare at least 2 approaches
✅ **Do** profile before optimizing
✅ **Do** track results over time

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **property-based-testing** | For testing correctness before optimization |
| **telemetry-essentials** | For production performance monitoring |
| **code-quality** | For overall code quality |
