# Elixir/Phoenix skill review

Review changed skills and docs for correctness, useful domain-specific guidance, portable references, and consistency with `directory.json` and `skills.sh.json`.

Report only concrete defects with file and line. Check that:

- Skill frontmatter names match folder and registry keys.
- Local links and assets resolve; no machine-specific paths or generated reports are added.
- `elixir-essentials` is the only shared language baseline; domain skills do not copy the same FCIS block.
- Version-sensitive Ecto, Phoenix, and dependency claims are supported by the project version or an authoritative reference.
- Tests, security checks, and high-risk checkpoints are scoped to the affected behavior.

Keep review output short. If no actionable issue exists, say so and list any checks not run.
