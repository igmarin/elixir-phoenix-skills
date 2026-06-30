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
---

# Benchee Profiling

## Rules & Workflow — Follow these in order with no exceptions

1. **Profile first** — run `:fprof` or `:eprof` and verify the output explicitly names the expected slow call site; re-run with a larger workload if ambiguous
2. **Write a comparative benchmark** — implement at least 2 alternative approaches using Benchee, ensuring implementations do the same thing; benchmark in `MIX_ENV=prod` for realistic results
3. **Use multiple inputs** — test with small, medium, and large realistic data sizes to catch size-dependent behavior
4. **Warm up before measuring** — use `warmup: 2` and `time: 10`; repeat 3–5 times to rule out variance; if results are within noise (< 5% difference), run 3 additional times
5. **Validate improvement** — confirm the faster approach wins across all input sizes
6. **Save baseline and check regressions** — write results to `bench/baseline.json`; raise an error if performance degrades more than 10% (compare against the previous 3 baselines before raising to rule out noise)
7. **Separate I/O benchmarks** — never benchmark network or disk I/O in the same run as compute benchmarks


## Setup

```elixir
# mix.exs
defp deps do
  [
    {:benchee, "~> 1.3", only: :dev}
  ]
end
```


## Basic Benchmark with Full Configuration

Use this pattern as the starting point for any new benchmark — it covers timing, memory, multiple inputs, and formatted output in one call.

```elixir
# bench/list_benchmark.exs
Benchee.run(
  %{
    "Enum.sort" => fn list -> Enum.sort(list) end,
    "Enum.sort_by" => fn list -> Enum.sort_by(list, & &1) end
  },
  time: 10,              # Run each scenario for 10 seconds
  warmup: 2,             # Warm up for 2 seconds
  memory_time: 2,        # Measure memory usage
  reduction_time: 2,     # Measure reductions
  inputs: %{
    "small list"  => Enum.to_list(1..100),
    "medium list" => Enum.to_list(1..10_000),
    "large list"  => Enum.to_list(1..100_000)
  },
  formatters: [
    {Benchee.Formatters.Console, comparison: true},
    {Benchee.Formatters.HTML, file: "output/benchmark.html"}
  ]
)
```

```bash
# Run benchmark
MIX_ENV=prod mix run bench/list_benchmark.exs
```


## Comparing Real-World Implementations

Use this pattern when you have multiple concrete implementations of the same operation and need to confirm which is fastest across realistic data. Unlike the basic example above, this section demonstrates benchmarking non-trivial logic defined in a module.

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
  "reduce"        => fn -> StringOperations.concat_loop(strings) end,
  "join"          => fn -> StringOperations.concat_join(strings) end,
  "comprehension" => fn -> StringOperations.concat_comprehension(strings) end
})
```


## Profiling with :fprof

```elixir
:fprof.trace(:start, file: 'trace.trace')
MyApp.SlowFunction.run()
:fprof.trace(:stop)

:fprof.profile(file: 'trace.trace')
:fprof.analyse(dest: 'analysis.txt')
```


## Profiling with :eprof

```elixir
:eprof.start()

:eprof.start_profiling([self()])
MyApp.SlowFunction.run()
:eprof.stop_profiling()

:eprof.analyze()
:eprof.stop()
```


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


## Advanced Topics

### CI Integration

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

### Memory Profiling

```elixir
Benchee.run(
  %{
    "String manipulation" => fn ->
      list = for i <- 1..1000, do: "item_#{i}"
      Enum.join(list, ",")
    end,
    "Binary manipulation" => fn ->
      list = for i <- 1..1000, do: "item_#{i}"
      IO.iodata_to_binary(Enum.intersperse(list, ","))
    end
  },
  memory_time: 5,
  reduction_time: 5
)
```
