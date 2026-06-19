---
name: credo-config
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when setting up or customizing Credo for Elixir projects, configuring .credo.exs, or adding
  Credo to CI pipelines. Generates .credo.exs configuration files, writes custom check modules,
  configures strictness levels, and integrates Credo into CI pipelines.
  Trigger words: Credo, .credo.exs, linting, code style, static analysis, custom checks.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Credo Configuration

## RULES — Follow these with no exceptions

1. **Use `.credo.exs` for project-specific configuration** — don't rely on defaults alone
2. **Enable strict mode in CI** — catch more issues before merge
3. **Disable specific checks with comments** — `# credo:disable-for-next-line` for intentional violations
4. **Customize checks for your team** — adjust strictness based on project needs

---

## Setup Workflow

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

This creates `.credo.exs` in the project root with all available checks listed.

### 4. Customize `.credo.exs`

Edit the generated file to match your project's needs. See [Basic Configuration](#basic-configuration) below.

### 5. Verify Setup

```bash
mix credo
```

Success: Credo exits 0 and prints a summary with issue counts per category. If issues are found, review them — fix violations, adjust check configuration, or add inline disable comments for intentional exceptions.

### 6. Add to CI

See [CI Integration](#ci-integration) below.

---

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
- name: Credo
  run: mix credo --strict
```

Strict mode enables additional checks disabled by default. CI fails on any issue.

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

Create custom checks for project-specific patterns:

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

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| **code-quality** | For overall code quality |
| **typespec-dialyzer** | For type safety |
| **security-essentials** | For security scanning with Sobelow |
