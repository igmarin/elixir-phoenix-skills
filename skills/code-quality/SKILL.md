---
name: code-quality
type: atomic
description: Use for a targeted Elixir quality pass, Credo configuration, static analysis, or simplifying code without changing behavior.
metadata:
  user-invocable: "true"
---

# Code Quality

Inspect the changed path and the project's existing config first. Keep the smallest fix that improves correctness or clarity.

- Run the configured formatter and focused tests.
- If Credo is installed, use the repository's configured command; use `mix credo --strict` only when the project supports it.
- Configure Credo only when asked or when adding it is part of the task. Reuse generated/project configuration instead of replacing it wholesale.
- Run Sobelow or dependency audits for security-sensitive changes, not as a ritual for every edit.
- Refactor only with tests that protect the affected behavior. Do not invent numeric complexity thresholds.

Report the checks run and any failures. For a broader diff review, use `code-review`.
