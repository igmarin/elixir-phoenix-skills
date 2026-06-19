---
name: credo-config
type: atomic
license: MIT
description: >
  Use when setting up or customizing Credo for Elixir projects. Invoke before configuring .credo.exs
  or adding Credo to CI. Covers Credo setup, custom checks, strictness levels, and CI integration.
  Trigger words: Credo, .credo.exs, linting, code style, static analysis, custom checks.
metadata:
  version: 1.0.0
---

# Credo Configuration

Credo is a static code analysis tool for Elixir with a focus on code consistency and common pitfalls.

## RULES — Follow these with no exceptions

1. **Add Credo to all Elixir projects** — catch style violations and potential bugs early
2. **Use `.credo.exs` for project-specific configuration** — don't rely on defaults alone
3. **Enable strict mode in CI** — catch more issues before merge
4. **Disable specific checks with comments** — `# credo:disable-for-next-line` for intentional violations
5. **Run Credo before committing** — make it part of your development workflow
6. **Customize checks for your team** — adjust strictness based on project needs

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
  ]
end
```

---

## Basic Configuration

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
      plugins: [],
      requires: [],
      checks: %{
        enabled: [
          # Consistency checks
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Design checks
          {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.TagTODO, [exit_status: 2]},
          {Credo.Check.Design.TagFIXME, []},

          # Readability checks
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring checks
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FunctionArity, []},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          # Warning checks
          {Credo.Check.Warning.ExpensiveOperationEnum, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
        ],
        disabled: [
          # Checks you don't want to run
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Design.DuplicatedCode, []},
        ]
      }
    }
  ]
}
```

---

## Running Credo

```bash
# Run with default config
mix credo

# Run in strict mode
mix credo --strict

# Run on specific files
mix credo lib/my_app/accounts.ex

# Show only warnings and above
mix credo --only warning

# Suggest fixes
mix credo suggest

# List all checks
mix credo list-checks
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

  def run(source_file, params) do
    # Custom check logic
    # ...
  end
end
```

---

## Common Pitfalls

❌ **Don't** skip Credo in CI
❌ **Don't** disable all checks — customize for your team
❌ **Don't** ignore warnings without documenting why
❌ **Don't** use Credo as the only quality tool — combine with Sobelow, Dialyzer

✅ **Do** add Credo to all projects
✅ **Do** use `.credo.exs` for configuration
✅ **Do** run Credo before committing
✅ **Do** enable strict mode in CI
✅ **Do** combine with other quality tools

## Integration

| Skill | When to chain |
|-------|---------------|
| **code-quality** | For overall code quality |
| **typespec-dialyzer** | For type safety |
| **security-essentials** | For security scanning with Sobelow |
