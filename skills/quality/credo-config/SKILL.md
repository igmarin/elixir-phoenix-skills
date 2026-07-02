---
name: credo-config
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for all code quality and linting work. Use when setting up or customizing Credo for
  Elixir projects, configuring .credo.exs, or adding Credo to CI pipelines. Generates .credo.exs
  configuration files, writes custom check modules, configures strictness levels, and integrates
  Credo into CI pipelines.
  Trigger words: Credo, .credo.exs, linting, code style, static analysis, custom checks, credo.config,

  mix credo, code quality, lint, static analysis, format check.
---

# Credo Configuration

## RULES — Follow these with no exceptions

1. **Always run `mix credo gen.config` first** — never hand-craft .credo.exs from scratch
2. **Use `--strict` in CI** — enables additional checks that are disabled by default
3. **Add inline disables sparingly** — document why each exception is necessary
4. **Custom checks belong in `lib/credo/checks/`** — never inline them in application code


## Setup Workflow

Follow this sequence when setting up or customizing Credo:

### 1. Add Dependency

```elixir
# mix.exs
defp deps do
  [
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  ]
end
```

### 2. Fetch Dependencies

```bash
mix deps.get
```

### 3. Generate Default Config

```bash
mix credo gen.config
```

### 4. Customize `.credo.exs`

See [Basic Configuration](#basic-configuration) below.

### 5. Verify Setup

```bash
mix credo
```

Success: Credo exits 0 and prints a summary with issue counts per category. If issues are found, review them — fix violations, adjust check configuration, or add inline disable comments for intentional exceptions.

### 6. Run in Strict Mode

```bash
mix credo --strict
```

CI must use `--strict`.

### 7. Add to CI

See [CI Integration](#ci-integration) below.

### 8. Create Custom Checks

Add custom check modules to `lib/credo/checks/`. See [Custom Checks](#custom-checks) below.


## Basic Configuration

> Use `mix credo gen.config` for the complete check list rather than writing it by hand.

```elixir
# .credo.exs
%{
  configs: [
    %{
      name: "default",
      strict: false,
      color: true,
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        enabled: [
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          # ... add or override checks as needed
        ],
        disabled: [
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Design.DuplicatedCode, []},
        ]
      }
    },
    %{
      name: "strict",
      strict: true,
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        enabled: [
          {Credo.Check.Design.TagTODO, [priority: :high]},
          {Credo.Check.Readability.Specs, []},
        ]
      }
    }
  ]
}
```


## Disabling Checks

### For a Single Line

```elixir
# credo:disable-for-next-line
def my_function_with_long_name, do: :ok

def my_function, do: :ok # credo:disable-for-this-line
```

### For a File

```elixir
# At the top of the file
# credo:disable-for-this-file Credo.Check.Readability.ModuleDoc

defmodule MyApp.LegacyModule do
  # No module doc needed
end
```

### In Configuration

```elixir
# .credo.exs
checks: %{
  disabled: [
    {Credo.Check.Readability.ModuleDoc, []}
  ]
}
```


## CI Integration

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  credo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26.0'
      - run: mix deps.get
      - run: mix credo --strict
```

### Handling Failures in CI

When Credo fails in CI, run `mix credo` locally to reproduce the failure. Only disable a check if it's a confirmed false positive — document the reason inline.

### Mix Alias

```elixir
# mix.exs
defp aliases do
  [
    "lint": ["credo --strict"],
    "quality": ["format --check-formatted", "credo --strict", "sobelow --config"]
  ]
end
```


## Custom Checks

Create custom checks for project-specific patterns in three steps:

1. Define a module using `use Credo.Check` in `lib/credo/checks/`.
2. Implement `run/2` with `Credo.Code.prewalk/2` to traverse the AST and collect issues.
3. Register the module under `checks.enabled` in `.credo.exs`.

The example below detects direct `Repo.` calls inside LiveView modules — adapt `find_issues/3` to match your own patterns:

```elixir
# lib/credo/checks/no_direct_repo_in_live_view.ex
defmodule Credo.Check.NoDirectRepoInLiveView do
  use Credo.Check, category: :design, base_priority: :high

  @explanation """
  LiveViews should not call Repo directly. Use context functions instead.
  """

  def run(%Credo.SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&find_issues(&1, &2, issue_meta))
  end

  # Detect calls of the form MyApp.Repo.<any function>
  defp find_issues(
         {{:., _, [{:__aliases__, meta, [_, "Repo"]}, _fn]}, _, _} = ast,
         issues,
         issue_meta
       ) do
    issue = format_issue(issue_meta, message: "Avoid direct Repo calls in LiveViews.", line_no: meta[:line])
    {ast, [issue | issues]}
  end

  defp find_issues(ast, issues, _issue_meta), do: {ast, issues}
end
```

Register the custom check in `.credo.exs`:

```elixir
checks: %{
  enabled: [
    {Credo.Check.NoDirectRepoInLiveView, []}
  ]
}
```


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Hand-write `.credo.exs` from scratch | Generate the baseline with `mix credo gen.config` |
| Run plain `mix credo` in CI | Run `mix credo --strict` in CI |
| Add Credo as a runtime dependency | Scope it: `only: [:dev, :test], runtime: false` |
| Scatter inline disables without explanation | Document why each `credo:disable-*` exception exists |
| Inline custom checks in application code | Put custom checks in `lib/credo/checks/` |
| Pin CI actions to `@latest` or `@main` | Pin to a specific version tag (e.g. `@v4`) |


## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| None (standalone) | credo-config | code-quality |
| code-quality | credo-config | code-review |

**Companion skills:**
- `code-quality` — runs `mix credo --strict` against this configuration
- `code-review` — enforces the same conventions during PR review
