# Skill Taxonomy

Domain-first organization for `elixir-phoenix-skills`. Place skills by **what they teach**, not by “quality vs feature.”

## Why domain-first

| Benefit | Effect for agents and humans |
|---------|------------------------------|
| **Context precision** | Loading `ecto-essentials` brings Ecto rules without unrelated workflow prose |
| **Clearer routing** | Router maps intent → one skill; fewer competing retrievals |
| **Scalable maintenance** | New LiveView guidance lives in Phoenix skills only |

## Tree

Physical layout is flat so `npx skills add` can pick **all** or **one**:

```text
skills/<name>/SKILL.md
```

Display groups (Elixir Core, Phoenix, Database, Playbooks, Orchestration, …) live in `skills.sh.json`. Skill kind is `type` in frontmatter (`atomic`, `playbook`, `orchestrator`).

## Kind responsibilities

| Kind | Owns | Does not own |
|------|------|--------------|
| Atomic | One domain: rules, examples, assets | Multi-step HITL workflow |
| Playbook | Sequenced phases, hard gates, HITL | Deep domain teaching (load atomics) |
| Orchestrator | Which skill/playbook to load next | Implementing features |

## Skill kinds

| Kind | `type` frontmatter | Role |
|------|--------------------|------|
| Atomic | `atomic` | Teach one domain well (rules + examples + assets) |
| Playbook | `playbook` | Multi-step process with gates and human checkpoints |
| Orchestrator | `orchestrator` | Route only; never implement |

## Migration matrix (completed in Phase 1 / #26)

| Existing path | New path |
|---------------|----------|
| `fundamentals/*` | `elixir-core/*` |
| `personas/*` | `playbooks/*` |
| `quality/apply-phoenix-liveview-conventions` | `phoenix/apply-phoenix-liveview-conventions` |
| `quality/apply-phoenix-controller-conventions` | `phoenix/apply-phoenix-controller-conventions` |
| `quality/apply-ecto-conventions` | `database/apply-ecto-conventions` |
| `phoenix/phoenix-scopes` | `auth/phoenix-scopes` |
| `infrastructure/telemetry-essentials` | `performance/telemetry-essentials` |
| `testing/benchee-profiling` | `performance/benchee-profiling` |

## Placement checklist

When adding a skill:

1. What domain does a developer search for first? → that skill id at `skills/<name>/`.
2. Is it a multi-step process with approvals? → `type: playbook`.
3. Is it only “which skill next?” → `type: orchestrator`.
4. Add a `skills.sh.json` grouping entry for marketplace display.
5. Prefer **one** home; link from others via Integration tables.

## Catalog sources of truth

- Paths: `directory.json`
- Install groupings: `skills.sh.json`
- Router map: `skills/elixir-skill-router/assets/skill-map.json`

## Skill frontmatter schema

Atomic skills use YAML frontmatter consumed by catalogs and agent loaders:

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | Skill id (matches folder) |
| `type` | yes | `atomic`, `playbook`, or `orchestrator` |
| `tags` | yes | e.g. `[atomic]` |
| `license` | yes | Usually `MIT` |
| `description` | yes | Triggers + when to use |
| `metadata.version` | yes | Semver string, e.g. `"1.0.0"` |
| `metadata.user-invocable` | atomic (recommended) | String `"true"` when agents may invoke the skill directly. Required for atomics in this library; playbooks/orchestrators should set it when user-invocable, optional otherwise. |
| `metadata.entry_point` | playbooks (recommended) | Boolean `true` when the skill is a multi-step entry workflow agents may start from (playbooks). Orchestrator is separate (`type: orchestrator`). Optional on atomics. |

Playbooks may also define `metadata.entry_point`, `metadata.phases`, `metadata.hard_gates`, and `metadata.dependencies` (see [playbooks.md](playbooks.md)).

## Router skill-map

`skills/elixir-skill-router/assets/skill-map.json` maps intents → skills.

- Prefer **playbook** mappings for multi-step work (`tdd`, `bug-fix`, `quality`, …).
- Prefer **atomic** mappings for single-domain implementation.
- `defaults` lists recommended skill paths for common flows.
- `disambiguation` resolves playbook vs atomic collisions (e.g. review workflow vs review rules).
