# String Concatenation Performance Analysis

## Problem/Feature Description

The data-processing team at a mid-sized SaaS company has noticed their reporting pipeline is slower than expected when generating large CSV-like outputs from lists of values. The pipeline assembles thousands of rows by joining field values into delimited strings, and on production loads the job takes longer than the acceptable window.

Before rewriting any production code, the engineering lead wants a rigorous benchmark comparing the main idiomatic approaches for building a long string from a list of values in Elixir. Specifically, the team is considering three patterns:

1. Repeated string concatenation using `<>` inside a `Enum.reduce` loop
2. `Enum.join/2` (the stdlib convenience function)
3. Building an iolist with `Enum.intersperse/2` and converting with `IO.iodata_to_binary/1`

The team needs the benchmark to be credible enough to guide a production optimization decision, which means it must account for how performance scales with different list sizes, measure both speed and memory, and produce a clear side-by-side comparison of the alternatives.

## Output Specification

Write a self-contained Elixir script at `bench/string_ops_benchmark.exs` that benchmarks the string concatenation approaches described above. The script should:

- Compare at least two of the listed approaches (the third is optional but welcome)
- Be runnable from the project root with a single shell command; include a brief comment near the top of the file explaining the exact command used to run it
- Produce a console report showing the relative performance of the alternatives
- Leave no large intermediate files on disk after it finishes

The script is the primary deliverable — the grader will read its source to assess how well it follows benchmarking best practices.
