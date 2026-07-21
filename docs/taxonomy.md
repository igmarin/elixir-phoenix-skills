# Skill Taxonomy

Domain-first organization for `elixir-phoenix-skills`. Place skills by **what they teach**, not by “quality vs feature.”

## Why domain-first

| Benefit | Effect for agents and humans |
|---------|------------------------------|
| **Context precision** | Loading `database/` brings Ecto rules without unrelated workflow prose |
| **Clearer routing** | Router maps intent → one domain folder; fewer competing retrievals |
| **Scalable maintenance** | New LiveView guidance lives under `phoenix/` only |

## Tree

```text
skills/
├── elixir-core/       # Pure FP, OTP, typespecs, Dialyzer
├── phoenix/           # LiveView, controllers, channels, Phoenix conventions
├── database/          # Ecto, migrations, changesets, Multi, Ecto conventions
├── auth/              # Scopes, phx.gen.auth, policies
├── security/          # Cross-cutting hardening (OWASP, secrets)
├── infrastructure/    # Oban, Broadway, Cachex, deployment-gotchas
├── integrations/      # Req, Swoosh, Gettext
├── frameworks/        # Ash and niche frameworks
├── testing/           # ExUnit, property-based tests
├── performance/       # Benchee + Telemetry
├── quality/           # Credo, code-quality, refactor, atomic review rules
├── tooling/           # Mix tasks and generators
├── playbooks/         # Multi-step HITL orchestrations
└── orchestration/     # elixir-skill-router only (meta-routing)
```

## Folder responsibilities

| Folder | Owns | Does not own |
|--------|------|--------------|
| `elixir-core/` | Language, OTP, types | Framework APIs |
| `phoenix/` | HTTP/LiveView/channels conventions | Auth scopes (→ `auth/`) |
| `database/` | Ecto schemas, queries, Multi | Job workers (→ `infrastructure/`) |
| `auth/` | AuthN/AuthZ, Scopes | Generic OWASP (→ `security/`) |
| `security/` | Risk-focused hardening | Credo style (→ `quality/`) |
| `infrastructure/` | Runtime engines & deploy | Profiling metrics (→ `performance/`) |
| `integrations/` | Boundary adapters (HTTP, mail, i18n) | Domain business rules |
| `frameworks/` | Ash (or similar) as a stack | Phoenix/Ecto defaults |
| `testing/` | Pass/fail test patterns | Benchmarks (→ `performance/`) |
| `performance/` | Measure & observe runtime | Job pipeline design |
| `quality/` | Static analysis, refactor, **atomic** review rules | Full review **workflow** (→ `playbooks/`) |
| `tooling/` | Mix CLI / generators | App business logic |
| `playbooks/` | Sequenced phases, hard gates, HITL | Deep domain teaching (link atomics) |
| `orchestration/` | Which skill/playbook to load | Implementing features |

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

1. What domain does a developer search for first? → that folder.
2. Is it a multi-step process with approvals? → `playbooks/`.
3. Is it only “which skill next?” → `orchestration/`.
4. Is it style/static analysis without owning a domain? → `quality/`.
5. Prefer **one** home; link from others via Integration tables.

## Catalog sources of truth

- Paths: `directory.json`
- Install groupings: `skills.sh.json`
- Router map: `skills/orchestration/elixir-skill-router/assets/skill-map.json`

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

`skills/orchestration/elixir-skill-router/assets/skill-map.json` maps intents → skills.

- Prefer **playbook** mappings for multi-step work (`tdd`, `bug-fix`, `quality`, …).
- Prefer **atomic** mappings for single-domain implementation.
- `defaults` lists recommended skill paths for common flows.
- `disambiguation` resolves playbook vs atomic collisions (e.g. review workflow vs review rules).
