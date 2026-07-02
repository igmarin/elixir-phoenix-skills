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

## RULES — Follow these with no exceptions

1. **Profile before you benchmark** — use `:fprof` or `:eprof` to confirm the actual bottleneck before writing any Benchee benchmark
2. **Always run benchmarks under `MIX_ENV=prod`** — dev-mode measurements are misleading because compile-time optimizations differ
3. **Include a `warmup:` phase** — let the BEAM and JIT settle before Benchee records measurements
4. **Compare at least two implementations that produce identical results** — a benchmark of a single function proves nothing about the alternative
5. **Validate across input sizes with `inputs:`** — small, medium, and large realistic datasets catch size-dependent behavior
6. **Never mix I/O and compute in one run** — benchmark network or disk work separately from CPU-bound code
7. **Guard regressions against a saved baseline** — compare with a >10% threshold and check recent baseline runs before failing to rule out noise

---

## Workflow

Follow these steps in order — do not skip profiling or go straight to benchmarking.

1. **Profile with `:fprof` or `:eprof`** — identify which function is the actual bottleneck; verify the output explicitly names the expected slow call site before proceeding. If ambiguous, re-run with a larger workload to amplify signal.

2. **Confirm the bottleneck** — do not write any benchmarks until the slow call site is identified. _(Never benchmark network or disk I/O in the same run as compute benchmarks.)_

3. **Write a comparative Benchee benchmark** — implement at least 2 alternative approaches that produce the same result. Run under `MIX_ENV=prod` for realistic results. Use `time: 10` (10 seconds) for reliable measurements; run 3–5 times to rule out variance. Include a `warmup:` phase to let JIT compilation settle.

4. **Validate across input sizes** — use `inputs:` with small, medium, and large realistic datasets to catch size-dependent behavior. If results are within noise (< 5% difference), run 3 additional times before drawing conclusions.

5. **Save baseline and check for regressions** — write results to `bench/baseline.json` with a >10% threshold. If a regression is detected, compare against the previous 3 baseline runs before raising an error to rule out noise.

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

## Benchmark Configuration

The canonical benchmark pattern — use `inputs:` for size-dependent validation, `memory_time:` and `reduction_time:` for resource profiling, and the HTML formatter for shareable reports:

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

```bash
# Run benchmark
MIX_ENV=prod mix run bench/list_benchmark.exs
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

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Benchmark in the `:dev` environment | Run under `MIX_ENV=prod mix run bench/...` |
| Guess the bottleneck and optimize blindly | Profile with `:fprof`/`:eprof` first, then benchmark |
| Skip `warmup:` and measure a cold BEAM | Always include a `warmup:` phase |
| Test a single input size | Use `inputs:` with small, medium, and large datasets |
| Mix network/disk I/O with compute in one run | Isolate I/O benchmarks from CPU-bound ones |
| Draw conclusions from one noisy run | Run 3–5 times and compare against recent baselines |
| Optimize with no recorded baseline | Save `bench/baseline.json` and check a >10% regression threshold |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| testing-essentials | benchee-profiling | telemetry-essentials |
| code-quality | benchee-profiling | deployment-gotchas |

**Companion skills:**
- `telemetry-essentials` — production-time measurement to complement offline benchmarks
- `code-quality` — apply idiomatic refactors before and after measuring
- `testing-essentials` — verify behaviour is correct before optimizing for speed
