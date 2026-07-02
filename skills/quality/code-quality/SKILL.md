---
name: code-quality
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for all code quality and refactoring work for Elixir. Use when analyzing or refactoring
  Elixir code. Covers duplication detection, ABC complexity, unused private functions, template
  duplication, and Credo integration. Provides thresholds and fix patterns for each quality issue.
  Trigger words: code quality, duplication, complexity, unused functions, Credo, refactoring, analysis,
  mix credo, abc complexity, function length, module length, refactor, extract function, shared code,
  code smell, technical debt, clean code.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Code Quality

## RULES — Follow these with no exceptions

1. **Duplicated functions must be extracted** — when 2+ modules share >70% similar implementations, create a shared module
2. **Functions must stay below ABC complexity 30** — break complex functions into smaller helpers
3. **Remove unused private functions after refactoring**
4. **Duplicated templates must become components** — when 2+ HEEx files share >40% identical markup, extract to a function component
5. **Address duplication before complexity** — extracting shared code first reduces overall complexity
6. **Run `mix credo --strict` before any PR**
7. **Run `mix sobelow` for security** — check after quality checks

---

## End-to-End Workflow

1. **Run analysis** — `mix credo --strict` to identify all issues
2. **Fix by priority** — address duplication first (Rule 5), then complexity, then unused functions
3. **Verify fixes** — re-run `mix credo --strict` to confirm all issues are resolved
4. **Security check** — run `mix sobelow` before committing
5. **Commit** — only after both Credo and Sobelow pass cleanly

---

## What Gets Detected

See [`assets/refactoring_checklist.md`](assets/refactoring_checklist.md) for the full complexity thresholds table and a copy-paste before/during/after refactoring checklist.

### Code Duplication

Cross-module functions with >70% similar bodies → extract to shared module.

❌ **Bad — the same formatting logic copy-pasted across LiveViews:**
```elixir
# lib/app_web/live/report_live.ex
defp format_time(seconds) when is_number(seconds) do
  # duplicated formatting logic
end

# lib/app_web/live/dashboard_live.ex
defp format_time(seconds) when is_number(seconds) do
  # identical formatting logic again
end
```

✅ **Good — extract to a shared module and import it:**
```elixir
# Create: lib/app_web/live/helpers.ex
defmodule AppWeb.Live.Helpers do
  def format_time(%Decimal{} = seconds) do
    seconds |> Decimal.to_float() |> format_time()
  end

  def format_time(seconds) when is_number(seconds) do
    # shared formatting logic
  end
end

# In each LiveView:
import AppWeb.Live.Helpers, only: [format_time: 1]
```

### ABC Complexity

❌ **Bad — one large function (complexity 41):**
```elixir
def calculate_trend_line(data) do
  # 50 lines of assignments, branches, conditions
end
```

✅ **Good — composed smaller functions (complexity <20 each):**
```elixir
def calculate_trend_line(data) do
  sums = calculate_regression_sums(data)
  slope = calculate_slope(sums)
  intercept = calculate_intercept(sums, slope)
  build_trend_points(data, slope, intercept)
end
```

### Unused Private Functions

After refactoring, scan for any private functions no longer referenced and remove them.

### Template Duplication

❌ **Bad — identical filter markup duplicated across HEEx templates:**
```heex
<!-- lib/app_web/live/report_live.html.heex and dashboard_live.html.heex -->
<div class="filters">
  <!-- the same filter markup repeated in both files -->
</div>
```

✅ **Good — extract to a reusable function component:**
```elixir
# Create a function component for the shared markup
defmodule AppWeb.Live.Components do
  use Phoenix.Component

  def metric_filters(assigns) do
    ~H"""
    <div class="filters">
      <!-- shared filter markup -->
    </div>
    """
  end
end
```

---

## Running Analysis

### Credo (Static Analysis)

```bash
# Run with strict mode (recommended)
mix credo --strict

# Focus on a specific file
mix credo lib/my_app/accounts.ex
```

### Sobelow (Security)

```bash
# Run security analysis
mix sobelow

# With configuration
mix sobelow --config
```

### Dependency Auditing

```bash
# All three in sequence
mix deps.audit && mix hex.audit && mix sobelow
```

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Fix ABC complexity before removing duplication | Address duplication first — extracting shared code lowers complexity (Rule 5) |
| Leave private functions behind after extracting shared code | Scan for and delete unused private functions after refactoring |
| Copy-paste HEEx markup across templates | Extract shared markup into a function component |
| Extract a shared module for barely-similar functions | Only extract when 2+ modules share >70% similar bodies |
| Let one giant function grow unbounded | Break functions above ABC complexity 30 into named helpers |
| Skip `mix sobelow` after quality fixes | Run `mix sobelow` for security before committing |
| Commit while Credo still reports issues | Commit only after `mix credo --strict` and `mix sobelow` pass cleanly |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| refactor-code | code-quality | code-review |
| testing-essentials | code-quality | credo-config |

**Companion skills:**
- `credo-config` — set up and customize the Credo checks this skill runs
- `refactor-code` — behavior-preserving extractions to resolve duplication and complexity
- `code-review` — human-facing review gate after automated quality checks pass
