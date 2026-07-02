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
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Credo Configuration

## RULES — Follow these with no exceptions

1. **Always run `mix credo gen.config` first** — never hand-craft .credo.exs from scratch
2. **Use `--strict` in CI** — enables additional checks that are disabled by default
3. **Add inline disables sparingly** — document why each exception is necessary
4. **Custom checks belong in `lib/credo/checks/`** — never inline them in application code

---

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

Edit the generated file to match your project's needs. See [Basic Configuration](#basic-configuration) below.

### 5. Verify Setup

```bash
mix credo
```

Fix violations, adjust check configuration, or add inline disable comments for intentional exceptions.

### 6. Run in Strict Mode

```bash
mix credo --strict
```

CI must use `--strict`.

### 7. Add to CI

See [CI Integration](#ci-integration) below.

### 8. Create Custom Checks

For project-specific patterns, add custom check modules to `lib/credo/checks/`. See [Custom Checks](#custom-checks) below.

---

## Basic Configuration

> Use `mix credo gen.config` for the complete check list. The example below shows how to override specific checks in the generated file — only include the checks you are changing.

```elixir
# .credo.exs (overrides only — start from gen.config output)
%{
  configs: [
    %{
      name: "default",
      strict: false,
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        enabled: [
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 0]}
        ],
        disabled: [
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Design.DuplicatedCode, []}
        ]
      }
    }
  ]
}
```

---

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

---

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

---

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

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Hand-craft `.credo.exs` from scratch | Run `mix credo gen.config` first, then override only what you change |
| Run `mix credo` without `--strict` in CI | Use `mix credo --strict` in CI so default-disabled checks run |
| Blanket-disable a check with no explanation | Document why each disable or inline exception is necessary |
| Inline custom checks in application modules | Keep custom check modules in `lib/credo/checks/` |
| Disable a check for a whole file when one line offends | Prefer `# credo:disable-for-next-line` for a single case |
| Copy the entire generated check list into version control edits | Commit only the overrides block; regenerate the full list with `gen.config` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| code-quality | credo-config | code-review |
| None (standalone) | credo-config | PR submission |

**Companion skills:**
- `code-quality` — runs `mix credo --strict` as part of the quality gate this skill configures
