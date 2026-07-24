# Companion guides (`agents/`)

Long-form reference docs adapted from the community Elixir/Phoenix guide.  
They are **not** agent skills (no `SKILL.md` frontmatter, not listed in `directory.json`).

For the agent-facing source of truth, see [`AGENTS.md`](../AGENTS.md).

| Guide | Use with skill |
|-------|----------------|
| [ecto-conventions.md](ecto-conventions.md) | `ecto-essentials`, `apply-ecto-conventions` |
| [liveview-checklist.md](liveview-checklist.md) | `phoenix-liveview-essentials`, `liveview` playbook |
| [testing-guide.md](testing-guide.md) | `testing-essentials`, `tdd` playbook |
| [project-structure.md](project-structure.md) | `setup` playbook, project bootstrap |

## Precedence

1. **Skills + playbooks** under `skills/` (and `docs/fcis-engineering-rules.md`) win on conflicts.
2. These guides supply extra examples and checklists only.
3. Prefer **FCIS** (Functional Core, Imperative Shell): pure core, thin LiveView/controller/worker edges — see [`docs/fcis-engineering-rules.md`](../docs/fcis-engineering-rules.md).

When in doubt, follow the skill `SKILL.md`, not this folder.
