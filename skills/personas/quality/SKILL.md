---
name: quality
type: persona
tags: [personas]
license: MIT
description: >
  Complete code quality loop for Elixir projects with hard gates: enforce formatting and linter compliance (mix format, mix credo must pass) → refactor only after characterization tests PASS on current code, verify behavior preserved after each extraction → generate @doc for all public APIs → NEVER open PR before formatter, credo, dialyzer, full test suite, and @doc coverage all pass; phases conventions review→refactoring→documentation. Use this composite end-to-end loop instead of individual refactoring or documentation skills when full three-phase production-readiness review is needed in one pass. Trigger: code review prep, before PR, full Elixir quality sweep, quality audit, production-ready review, end-to-end quality check.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when conducting full production-readiness review or code quality sweep before PR"
  phases: "Phase 1: Conventions Review, Phase 2: Refactoring, Phase 3: Documentation"
  hard_gates: "Conventions Check, Refactoring Test Gate, Quality Before Merge"
  dependencies:
    - source: self
      skills: [code-quality, credo-config, typespec-dialyzer, security-essentials]
  keywords: elixir, quality, conventions, refactoring, documentation, credo, review
---
# Quality Persona

Orchestrates systematic code quality checks, safe refactoring, and documentation updates across three phases. Use this instead of individual refactoring or documentation skills when full production-readiness is required end-to-end.

## Complexity Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Function Length | > 20 lines | Extract function or private helper |
| Parameter Count | > 4 | Use keyword list or map |
| Module Length | > 400 lines | Extract context or sub-module |
| Nesting Depth | > 3 levels | Extract function or use `with` |
| Duplication | > 3 similar blocks | Extract shared module/function |
| Pipe Chain | > 5 pipes | Extract into named function |

## Agent Phases

### Phase 1: Conventions Review

Check code against Elixir standards via **quality/code-quality** (DRY, immutability, pattern matching, pipe discipline) and **quality/credo-config** (Credo rules compliance, code consistency, naming conventions).

**Key file patterns to review:** `lib/`, `test/`, `priv/`.

**Tool Integration:**
```bash
# Formatting
mix format --check-formatted

# Linting and complexity
mix credo --strict

# Type checking
mix dialyzer

# Security check (no Elixir equivalent of brakeman yet — manual review)
mix hex.audit
```

---

### Phase 2: Refactoring (Optional)

**Decision Gate — Proceed if any threshold from the table above is exceeded; otherwise skip to Phase 3.**

**If refactoring is needed, follow TDD discipline:**

### TDD Enforcement for Refactoring

**Before any code change:**
1. **testing/testing-essentials** — Write characterization test that documents current behavior.
2. **Verify test PASSES** — `mix test test/path/to/file_test.exs`.
3. **Refactoring Checkpoint** — Propose specific refactoring (e.g., "Extract `calculate_discount` to private function and add @doc").
4. **User Approval** — Wait for explicit confirmation.
5. **Implement Refactoring** — Make the structural change only.
6. **Verify PASS** — Run characterization test again.
7. **Regression Check** — Run `mix test` for full suite.

**HARD GATE — Test Verification:**
- Characterization test EXISTS and PASSES before refactoring
- Characterization test PASSES after refactoring (behavior preserved)
- Full test suite PASSES (no regressions)
- If test fails: Fix the refactoring, not the test

Follow **quality/code-quality** for specific extraction patterns and safety guidelines.

```bash
mix test   # All tests must pass before proceeding to Phase 3
```

---

### Phase 3: Documentation

Document public APIs:
1. **Add `@moduledoc`** to every public module.
2. **Add `@doc`** to every public function with description and examples.
3. **Add `@spec`** to every public function via **fundamentals/typespec-dialyzer**.

**Output:** Updated @moduledoc and @doc comments, refreshed README sections.

---

## HARD-GATE: Quality Before Merge

**NEVER open PR before:**
```bash
mix format --check-formatted        # Formatter must pass
mix credo --strict                  # Credo must pass
mix test                            # All tests must pass
mix dialyzer                        # No type warnings
mix hex.audit                       # Dependency audit
```
Plus: `@doc` and `@spec` annotations on all public APIs.

**If gate fails:** Fix the failing item before opening PR.

## Output Format

```markdown
# Quality Report — [Date]

## Conventions Check
### Critical Violations (Must Fix)
- [CRITICAL] lib/my_app/orders.ex:42 — Function `process_payment` has 35 lines (> 20 threshold)
- [CRITICAL] lib/my_app_web/live/user_live.ex:28 — Module has 520 lines (> 400 threshold)

### Warning Violations (Should Fix)
- [WARNING] lib/my_app/services.ex:17 — Function `calculate_discount` has 6 parameters (> 4 threshold)

### Suggestion Violations (Nice to Have)
- [SUGGESTION] test/my_app/order_test.exs:12 — Duplicate setup block, extract to private function

## Refactoring
- [x] / [ ] Required (threshold exceeded)
- Characterization tests added, functions extracted, all tests passing

## Documentation
- @doc coverage: 87% (improved from 65%)
- @spec coverage: 92% (improved from 70%)
```

---

## Error Recovery

**Credo violations after refactoring:**
1. Run `mix format` for auto-fixable formatting issues.
2. Run `mix credo --strict` to see all violations.
3. Fix violations manually — refactoring may have introduced new issues.

**Characterization test fails after refactoring:**
1. The refactoring changed behavior — this is a regression, not a test problem.
2. Revert the refactoring change.
3. Re-examine the extraction — ensure the new function/module preserves the exact contract.
4. Try a smaller, more focused refactoring step.

**Dialyzer errors after refactoring:**
1. Recompile with `mix compile --force`.
2. Run `mix dialyzer` to identify type inconsistencies.
3. Update `@spec` annotations to match the refactored code.

---

## Anti-Patterns to Avoid

- **Refactoring without tests:** NEVER refactor without characterization tests passing first.
- **Fixing tests to match refactoring:** If a test fails after refactoring, the refactoring broke behavior — fix the code, not the test.
- **Scope creep during quality pass:** Don't add features during a quality review — only fix conventions, refactor, and document.
- **Ignoring Credo warnings:** Every Credo violation MUST be assessed — false positives should be annotated, not silently ignored.
- **Skipping dialyzer:** Type errors caught by dialyzer are real bugs.

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|--------------|----------|
| tdd | quality | PR submission |
| code-quality | quality | review |
| None (standalone) | quality | PR submission |
