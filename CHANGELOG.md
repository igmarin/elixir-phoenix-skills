# Changelog

## Unreleased

- Preserve all 47 catalog identities and supporting resources. Normalize playbook/router dependency metadata to a list of source-and-skills groups without changing the catalog schema.
- Route small bugs directly to the reproduction workflow. Inspect actual Phoenix routes/auth conventions before choosing LiveView or scopes. Resolve scope before RED; load and execute the chosen workflow in the current agent when delegation is unavailable.
- Report missing required skills/resources as dependency blockers instead of silently replacing them with generic guidance.
- Continue authorized implementation through TDD, bug, LiveView, job, and quality workflows. Preserve failing-test, green-suite, idempotency, characterization, and production-execution gates.
- Correct required environment lookup to `System.fetch_env!`, controller plug terminology, valid LiveView reply tuples, existing-atom error classification, transaction guidance, and evidence-based review severity.
- Move `skills/playbooks/code-review/SKILL.md` to `skills/playbooks/code-review-playbook/SKILL.md` so its directory matches the existing `code-review-playbook` identity. Catalog consumers remain compatible; old direct-path consumers must use the new path. Composed bundles maintain the legacy mapping for one major release.
- Resolve the review playbook's checklist reference to the existing atomic review asset. The catalog validator now checks local Markdown links, inline bundled resources, and folder/name agreement; a negative-resource test prevents a return of the missing-checklist defect.

Validation: `python3 scripts/validate-catalog.py` and `python3 -m unittest discover -s scripts -p 'test_*.py'`. Structural checks cover all 47 skill trees; this is not a behavioral LLM evaluation or an assurance that every code example has been executed.
