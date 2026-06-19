---
name: code-quality
type: atomic
license: MIT
description: >
  Invoke when analyzing or refactoring Elixir code. Covers duplication detection, ABC complexity,
  unused private functions, template duplication, and Credo integration.
  Provides thresholds and fix patterns for each quality issue.
  Trigger words: code quality, duplication, complexity, unused functions, Credo, refactoring, analysis.
metadata:
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Code Quality

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill when analyzing or refactoring Elixir code.

## RULES — Follow these with no exceptions

1. **Duplicated functions must be extracted** — when 2+ modules share >70% identical function implementations, create a shared module
2. **Functions must stay below ABC complexity 30** — break complex functions into smaller helpers with single responsibilities
3. **Unused private functions must be removed** — dead code increases maintenance burden and confusion
4. **Duplicated templates must become components** — when 2+ HEEx files share >40% identical markup, extract to a function component
5. **Address duplication before complexity** — extracting shared code often reduces complexity as a side effect
6. **Prefer composition over inheritance** — extract shared functions into modules imported/used where needed
7. **Run Credo before committing** — `mix credo` catches style violations and potential bugs
8. **Run Sobelow for security** — `mix sobelow` catches security vulnerabilities

---

## What Gets Detected

### Code Duplication

Detects when the same function appears in multiple modules with >70% body similarity.

**How it works:** AST-based analysis parses function bodies and compares them using trigram similarity.

**Example output:**
```
  Duplication Detected
   Function `format_time/1` (85% similar)
     lib/app_web/live/cycle_time.ex:45
     lib/app_web/live/lead_time.ex:52
   Suggestion: Extract to a shared module
```

**How to fix:**
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

Measures function complexity using the ABC metric (Assignments, Branches, Conditions).

- **A (Assignments):** `=` operators
- **B (Branches):** `case`, `cond`, `if`, `unless`, `with`, `->` clauses
- **C (Conditions):** `&&`, `||`, `and`, `or`, `==`, `!=`, `>`, `<`, `>=`, `<=`, `when` guards

**ABC = sqrt(A² + B² + C²)** — threshold is 30.

**How to fix:**
```elixir
# Before: one large function (complexity 41)
def calculate_trend_line(data) do
  # 50 lines of assignments, branches, conditions
end

# After: composed smaller functions (complexity <20 each)
def calculate_trend_line(data) do
  sums = calculate_regression_sums(data)
  slope = calculate_slope(sums)
  intercept = calculate_intercept(sums, slope)
  build_trend_points(data, slope, intercept)
end
```

### Unused Private Functions

Detects `defp` functions that are defined but never called within the module.

**Common after refactoring** — when you extract code to a shared module, the original private functions may become dead code.

### Template Duplication

Detects when HEEx templates in the same directory share >40% identical markup.

**How to fix:**
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
# Run Credo with default config
mix credo

# Run with strict mode
mix credo --strict

# Show only warnings and above
mix credo --only warning

# Focus on a specific file
mix credo lib/my_app/accounts.ex
```

### Sobelow (Security)

```bash
# Run security analysis
mix sobelow

# With configuration
mix sobelow --config

# Skip specific checks
mix sobelow --skip Config.Secrets
```

### Dependency Auditing

```bash
# Check for known vulnerabilities
mix deps.audit

# Verify package checksums
mix hex.audit

# All three in sequence
mix deps.audit && mix hex.audit && mix sobelow
```

**Add to CI pipeline:**
```elixir
# In mix.exs aliases
defp aliases do
  [
    "security.check": ["deps.audit", "hex.audit", "sobelow --config"],
    "quality": ["format --check-formatted", "credo --strict", "sobelow --config"]
  ]
end
```

---

## Common Pitfalls

❌ **Don't** ignore Credo warnings — they catch real issues
❌ **Don't** leave unused private functions after refactoring
❌ **Don't** duplicate template markup across LiveViews
❌ **Don't** write functions with ABC complexity > 30
❌ **Don't** skip dependency audits after `mix deps.update`

✅ **Do** run `mix credo` before committing
✅ **Do** extract duplicated code into shared modules
✅ **Do** break complex functions into smaller helpers
✅ **Do** use function components for shared HEEx markup
✅ **Do** run `mix sobelow` regularly

## Integration

| Skill | When to chain |
|-------|---------------|
| **credo-config** | When setting up or customizing Credo configuration |
| **elixir-essentials** | When applying Elixir patterns during refactoring |
| **testing-essentials** | When ensuring test coverage after refactoring |
| **security-essentials** | When running security-focused quality checks |
