# Setting Up a Performance Benchmark Suite for an Elixir Data Processing Library

## Problem/Feature Description

Your team maintains an Elixir library that's used in production for high-throughput data pipelines. The library handles two distinct workloads: JSON serialization and deserialization of structured records (a compute-intensive task), and reading/writing configuration files from disk (an I/O-bound task). Over the past few months, a handful of unnoticed performance regressions have crept in during routine refactors — changes that looked harmless but quietly degraded throughput by 15-20%.

The team has decided to add a proper benchmarking setup using Benchee to catch future regressions before they ship. There's currently no `bench/` directory in the project at all. You need to scaffold the entire benchmark suite from scratch, including the project dependency, benchmark scripts for each workload type, an orchestration script, and a regression-detection script.

The project's `mix.exs` doesn't yet include Benchee. The team wants the benchmarks organized clearly so future contributors can easily add new scenarios, and they need automated regression detection that can be run in CI to guard against slowdowns.

## Output Specification

Create the following files:

- `bench/json_benchmark.exs` — Benchee benchmark script for JSON encoding/decoding operations. Include at least two competing approaches or input variations.
- `bench/file_io_benchmark.exs` — Benchee benchmark script for file read/write operations.
- `bench/suite.exs` — Orchestration script that runs the JSON/compute benchmarks.
- `bench/compare_with_baseline.exs` — Regression-detection script that compares current benchmark results against a stored baseline and reports whether performance has changed significantly.
- `bench/baseline.json` — A starter baseline file for the regression script to reference.
- `mix_deps_snippet.exs` — A code snippet showing the Benchee dependency entry to add to `mix.exs`.

All files should contain working Elixir code (even if illustrative). Do not leave any files larger than a few KB.
