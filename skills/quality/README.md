# Code Quality Skills

Skills for maintaining high engineering standards, code quality, and architectural integrity in Elixir and Phoenix applications.

## Skills

- **[code-quality](code-quality/)** — MANDATORY for all code quality and refactoring work. Covers duplication detection, ABC complexity, unused private functions, template duplication, and Credo integration.
- **[credo-config](credo-config/)** — MANDATORY for Credo setup and customization. Covers `.credo.exs` configuration, custom checks, strict mode, and CI integration.
- **[code-review](code-review/)** — Systematic Elixir/Phoenix PR review with severity levels, BEAM-specific checks, and structured findings output (atomic rules; see playbook for full review flow).
- **[refactor-code](refactor-code/)** — Safe Elixir code restructuring with characterization tests, stable behavior statements, and one-boundary-at-a-time extraction.
- **[respond-to-review](respond-to-review/)** — Evaluating and implementing code review feedback with classification, verification, and pushback with evidence.

> Domain conventions moved next to their domains:
> - LiveView/controller conventions → `skills/phoenix/`
> - Ecto conventions → `skills/database/`

## Quality Playbook

The **[quality](../../playbooks/quality/SKILL.md)** playbook orchestrates these skills in a three-phase production-readiness loop:

1. **Phase 1 — Conventions Review** — Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix hex.audit`
2. **Phase 2 — Refactoring** — Extract violations with characterization tests
3. **Phase 3 — Documentation** — Ensure all public APIs have `@doc` and `@spec`

Invoke the playbook when conducting full production-readiness review, code quality sweeps, or pre-PR checks.

## Trigger Words

Use these skills when you see:
- "code quality", "refactor", "duplication", "complexity", "Credo"
- "clean code", "extract function", "technical debt"
- "linter", "static analysis", "credo config", "mix credo"
- "before PR", "quality sweep", "production readiness"
- "code review", "PR review", "review my code", "code audit", "review diff"
- "respond to review", "PR feedback", "code review comments", "address review feedback"
