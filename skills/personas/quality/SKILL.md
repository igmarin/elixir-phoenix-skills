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

Orchestrates code quality checks, safe refactoring, and documentation updates across three phases.

## Complexity Thresholds

Proceed to Phase 2 if any of these non-default thresholds are exceeded:

| Metric | Threshold | Action |
|--------|-----------|--------|
| Function Length | > 20 lines | Extract function or private helper |
| Parameter Count | > 4 | Use keyword list or map |
| Module Length | > 400 lines | Extract context or sub-module |
| Nesting Depth | > 3 levels | Extract function or use `with` |
| Pipe Chain | > 5 pipes | Extract into named function |

## Agent Phases

### Phase 1: Conventions Review

Run the following tools and address all violations:

```bash
mix format --check-formatted   # Formatting
mix credo --strict             # Linting and complexity
mix dialyzer                   # Type checking
mix hex.audit                  # Dependency audit
```

---

### Phase 2: Refactoring (Optional)

**Decision Gate — Proceed if any threshold above is exceeded; otherwise skip to Phase 3.**

**TDD Enforcement — Before any code change:**
1. Write characterization test documenting current behavior.
2. **Verify PASSES** — `mix test test/path/to/file_test.exs`.
3. **Checkpoint** — Propose specific refactoring (e.g., "Extract `calculate_discount` to private function").
4. **User Approval** — Wait for explicit confirmation.
5. **Implement** — Make the structural change only.
6. **Verify PASSES** — Run characterization test again.
7. **Regression Check** — `mix test` for full suite.

**HARD GATE — Test Verification:**
- Characterization test EXISTS and PASSES before refactoring
- Characterization test PASSES after refactoring (behavior preserved)
- Full test suite PASSES (no regressions)
- If test fails: Fix the refactoring, not the test

```bash
mix test   # All tests must pass before proceeding to Phase 3
```

---

### Phase 3: Documentation

Document public APIs:
1. **Add `@moduledoc`** to every public module.
2. **Add `@doc`** to every public function with description and examples.
3. **Add `@spec`** to every public function.

**Output:** Updated @moduledoc and @doc comments, refreshed README sections.

---

## HARD-GATE: Quality Before Merge

**NEVER open PR before all Phase 1 checks pass** (`mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`, `mix hex.audit`) **plus `mix test`** (full suite green) **and `@doc`/`@spec` annotations on all public APIs.**

**If gate fails:** Fix the failing item before opening PR.

## Output Format

Produce a `# Quality Report — [Date]` with three sections:
- **Conventions Check**: list CRITICAL / WARNING / SUGGESTION violations with file path, line, and description.
- **Refactoring**: checked/unchecked required flag, summary of characterization tests added and functions extracted.
- **Documentation**: @doc and @spec coverage percentages before and after.

---

## Error Recovery

**Credo violations after refactoring:** Run `mix format` for auto-fixable issues, then fix remaining manually with `mix credo --strict`.

**Characterization test fails after refactoring:** Revert the change, re-examine the extraction to ensure the contract is preserved, then attempt a smaller, more focused refactoring step.

**Dialyzer errors after refactoring:** Recompile with `mix compile --force`, then update `@spec` annotations to match the refactored code.
