---
name: quality
type: persona
tags: [personas]
license: MIT
description: >
  Complete code quality loop for Elixir projects with hard gates: enforce formatting and linter compliance (mix format, mix credo must pass) → refactor only after characterization tests PASS on current code, verify behavior preserved after each extraction → generate @doc for all public APIs → NEVER open PR before formatter, credo, dialyzer, full test suite, and @doc coverage all pass; phases conventions review→refactoring→documentation. Use this composite end-to-end loop instead of individual refactoring or documentation skills when full three-phase production-readiness review is needed in one pass. Trigger: code review prep, before PR, full Elixir quality sweep, quality audit, production-ready review, end-to-end quality check.
---

# Quality Persona

Orchestrates code quality checks, safe refactoring, and documentation updates across three phases.

## Complexity Thresholds

Proceed to Phase 2 if any threshold is exceeded:

| Metric | Threshold | Action |
|--------|-----------|--------|
| Function Length | > 20 lines | Extract function or private helper |
| Parameter Count | > 4 | Use keyword list or map |
| Module Length | > 400 lines | Extract bounded context or sub-module |
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

**HARD GATE — NEVER open a PR before all four checks above pass**, plus `mix test` (full suite green) and `@doc`/`@spec` annotations on all public APIs (completed in Phase 3). Fix any failure before proceeding.

**If gate fails:** Fix the failing check — formatter, `credo`, `dialyzer`, `hex.audit`, or a red test — before doing anything else; do not open the PR until every command exits 0.


### Phase 2: Refactoring (Optional)

**Decision Gate — Proceed if any threshold above is exceeded; otherwise skip to Phase 3.**

**TDD Enforcement — Before any code change:**
1. Write characterization test documenting current behavior.
2. **Verify PASSES** — `mix test test/path/to/file_test.exs`.
3. **Checkpoint** — Propose specific refactoring (e.g., extract a private helper, introduce a `with` chain, replace positional args with a keyword list).
4. Apply the single proposed change.
5. **Re-validate** — `mix test test/path/to/file_test.exs` must still be green.
6. **Repeat** steps 3–5 for each additional violation; do not batch multiple extractions in one step.

**Error Recovery — If tests go red after a change:**
- Revert the last change immediately.
- Re-examine the characterization test to ensure it fully covers the behavior being touched.
- Propose a smaller, safer extraction and repeat from step 3.


### Phase 3: Documentation

**Goal — All public API functions have `@doc` and `@spec` before merge.**

1. Identify every public function (no leading `_`, not `defp`) in the changed modules.
2. For each function missing `@doc`:
   - Write a concise description of purpose and return value.
   - Add at least one `## Examples` block with a `iex>` doctest where practical.
3. For each function missing `@spec`:
   - Derive the typespec from usage and dialyzer hints.
   - Add `@spec` immediately above the function head.
4. Run `mix dialyzer` once more to confirm new typespecs are consistent.
5. Run `mix test` to verify doctests pass.


## Final Pre-PR Checklist

Before opening a PR, confirm every item is green:

| Check | Command | Must Pass |
|-------|---------|----------|
| Formatting | `mix format --check-formatted` | ✅ |
| Linting | `mix credo --strict` | ✅ |
| Type checking | `mix dialyzer` | ✅ |
| Dependency audit | `mix hex.audit` | ✅ |
| Full test suite | `mix test` | ✅ |
| Doc/spec coverage | All public APIs annotated | ✅ |

**Do not open the PR until every row is ✅.**


## Output Style

When completing a quality pass, output a report using this template:

```markdown
# Quality Report — [Module / Scope]

## Conventions
- mix format --check-formatted: ✓/✗
- mix credo --strict: ✓/✗ (<n> issues)
- mix dialyzer: ✓/✗
- mix hex.audit: ✓/✗

## Refactoring
- Thresholds exceeded: <list or none>
- Extractions applied: <list>, each re-validated green

## Documentation
- Public functions annotated: <n>/<n> @doc, <n>/<n> @spec
- Doctests passing: ✓/✗

## Full Suite
- mix test: ✓/✗ (<n> tests, 0 failures)

Verdict: <READY FOR PR / NOT READY — blocking check>
```


## Error Recovery

**Tests go red after a refactoring extraction:**
1. Revert the last change immediately.
2. Widen the characterization test to cover the touched behavior, then propose a smaller extraction.

**Credo flags an issue you believe is a false positive:**
1. Do not blanket-disable the check; confirm with the user before suppressing anything.
2. If the pattern is genuinely intentional, add a scoped `# credo:disable-for-next-line` with a justifying comment.

**Dialyzer reports a contract or type error after you add an `@spec`:**
1. Re-derive the spec from actual usage and dialyzer's hint.
2. If the code is correct but the spec is wrong, fix the spec; if the spec exposed a real type bug, fix the code.

**`mix hex.audit` reports a vulnerable dependency:**
1. Bump the affected dependency to a patched version and re-run the audit.
2. If no patched release exists, document the exposure and raise it with the user before opening the PR.
