# Performance Investigation for a List-Processing Module

## Problem/Feature Description

The team maintains an Elixir module that processes large datasets of user records for a reporting pipeline. Recently, a production deployment caused a noticeable slowdown in nightly batch jobs, and initial timing logs suggest the bottleneck is somewhere inside the list-processing module — but nobody is sure which function is actually responsible for the regression.

The module in question is provided at `inputs/list_processor.ex`. It contains two candidate functions: `slow_path/1` and `fast_path/1`, both of which transform a list of integer records. Before committing to an optimization effort, the team wants a thorough written investigation plan and a ready-to-run benchmark script skeleton they can drop into the project.

Your job is to produce a professional performance investigation plan and a working benchmark script template based on the module provided. The plan should guide a developer through the complete profiling and benchmarking process from start to finish, covering how to identify the actual culprit, how to confirm the finding, how to write a sound comparative benchmark, and how to establish a repeatable performance baseline. The benchmark script template should be a real `.exs` file that a developer can run with minor edits.

## Output Specification

Produce the following two files:

- **`bench/investigation_plan.md`** — A markdown document describing the full investigation process, including:
  - How to profile the module to determine which function is the bottleneck (include concrete Elixir/Erlang code for running the profiler)
  - How to interpret the profiling output to confirm the slow function has been correctly identified before moving on
  - How to write a comparative benchmark once the bottleneck is confirmed
  - How to determine whether an optimization is genuine vs. within measurement noise
  - How to record a performance baseline for future regression detection

- **`bench/benchmark_template.exs`** — An Elixir script skeleton ready to benchmark `slow_path/1` against `fast_path/1` with appropriate configuration for reliable, reproducible results. The script does not need to run successfully in isolation (the project's mix dependencies are not installed here), but it must be syntactically correct Elixir and reflect best practices for benchmarking configuration.
