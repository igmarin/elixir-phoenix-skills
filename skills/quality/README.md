# Code Quality Skills

Skills for maintaining high engineering standards, code quality, and architectural integrity in Elixir and Phoenix applications.

## Skills

- **[code-quality](code-quality/)** — MANDATORY for all code quality and refactoring work. Covers duplication detection, ABC complexity, unused private functions, template duplication, and Credo integration.
- **[credo-config](credo-config/)** — MANDATORY for Credo setup and customization. Covers `.credo.exs` configuration, custom checks, strict mode, and CI integration.
- **[apply-phoenix-liveview-conventions](apply-phoenix-liveview-conventions/)** — Enforces consistent LiveView patterns: mount/handle_event/handle_info callbacks, HEEx components, form binding, socket assigns, and error handling.
- **[apply-phoenix-controller-conventions](apply-phoenix-controller-conventions/)** — Enforces consistent Phoenix controller patterns: RESTful routing, plug pipeline, action methods, strong parameters, content negotiation, and fallback controllers.
- **[code-review](code-review/)** — Systematic Elixir/Phoenix PR review with severity levels, BEAM-specific checks, and structured findings output.

## Quality Persona

The **[quality](../../personas/quality/SKILL.md)** persona orchestrates these skills in a three-phase production-readiness loop:

1. **Phase 1 — Conventions Review** — Run `mix format`, `mix credo --strict`, `mix dialyzer`, `mix hex.audit`
2. **Phase 2 — Refactoring** — Extract violations with characterization tests
3. **Phase 3 — Documentation** — Ensure all public APIs have `@doc` and `@spec`

Invoke the persona when conducting full production-readiness review, code quality sweeps, or pre-PR checks.

## Trigger Words

Use these skills when you see:
- "code quality", "refactor", "duplication", "complexity", "Credo"
- "clean code", "extract function", "technical debt"
- "phoenix conventions", "liveview conventions", "follow phoenix patterns"
- "linter", "static analysis", "credo config", "mix credo"
- "before PR", "quality sweep", "production readiness"
- "code review", "PR review", "review my code", "code audit", "review diff"