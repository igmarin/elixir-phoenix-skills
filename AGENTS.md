# Agent guidance for `elixir-phoenix-skills`

This file is the single source of truth for AI agents working in this repository. It complements the human-facing `README.md` and the long-form docs under `docs/` and `agents/`.

## What this repo is

A curated, public library of **Elixir/Phoenix agent skills** — atomic skills, playbooks, and one orchestrator. The purpose of every skill is to make an AI agent produce idiomatic, production-ready Elixir and Phoenix code.

Core philosophy:

```text
Pattern matching over conditionals
Let it crash
Pipes for transformations
`with` for fallible operations
Functional Core, Imperative Shell (FCIS)
```

## Repository layout

```text
skills/
├── elixir-core/      # Language, OTP, typespecs, Dialyzer
├── phoenix/          # LiveView, controllers, channels, conventions
├── database/         # Ecto, migrations, changesets, Multi
├── auth/             # Scopes, phx.gen.auth, policies
├── security/         # Cross-cutting hardening
├── infrastructure/   # Oban, Broadway, Cachex, deployment-gotchas
├── integrations/     # Req, Swoosh, Gettext
├── frameworks/       # Ash and niche frameworks
├── testing/          # ExUnit, property-based tests
├── performance/      # Benchee + Telemetry
├── quality/          # Credo, code-quality, refactor, review rules
├── tooling/          # Mix tasks and generators
├── playbooks/        # Multi-step HITL orchestrations
└── orchestration/    # `elixir-skill-router` only
docs/                 # Cross-cutting design docs
agents/               # Long-form companion guides (not skills)
assets/               # Per-skill templates and checklists
scripts/              # Validation scripts
```

## Skill conventions

### Atomic skill (`type: atomic`)

- `tags: [atomic]` exactly.
- `description` starts with `MANDATORY for ALL <domain> work. Invoke before <condition>.` when the skill is mandatory, otherwise starts with a clear trigger statement.
- Must contain:
  - `## RULES — Follow these with no exceptions`
  - Good/bad (`✅` / `❌`) code examples
  - `## Common Pitfalls` table
  - `## Integration` table with predecessor / successor skills
- Place reusable templates/checklists under `assets/` inside the skill folder.

### Playbook (`type: playbook`)

- `tags: [playbooks]` exactly.
- `description` uses `Trigger:` (not `Trigger words:`).
- Must contain a top-level `## HARD-GATE` section.
- Standard sections: `## When to use`, `## Phases`, `## Verification checklist`, `## Error Recovery`, `## Output Style`.
- Playbooks orchestrate atomic skills; they do not re-teach domain textbooks.

### Orchestrator (`type: orchestrator`)

- `elixir-skill-router` routes intent to the correct skill/playbook.
- It does not implement features.

## Precedence when guidance conflicts

1. `SKILL.md` files in `skills/`
2. `AGENTS.md` (this file)
3. `docs/fcis-engineering-rules.md` and other `docs/`
4. `agents/` companion guides

## Validation

Run these before every commit and before opening a PR:

```bash
# 1. Catalog consistency
python3 scripts/validate-catalog.py

# 2. External review of staged changes (dry-run)
git diff --cached --unified=5 > /tmp/staged.diff
./bin/rs-guard-<platform> --diff-file /tmp/staged.diff --dry-run
```

`rs-guard` uses the existing `.reviewer.toml` and `.github/review-prompt.md` files for its rules. The platform binary is in `bin/` (e.g., `rs-guard-macos-arm64`, `rs-guard-linux-x64`). CI downloads the correct one automatically via `scripts/rs-guard-install.sh`.

## Workflow

1. **Branch** from `main`: `git checkout -b feature/<short-name>`.
2. **Work in small commits** that reference an issue: `Closes #<issue>`.
3. **Stage** changes and run `rs-guard` before each commit.
4. **Validate** with `python3 scripts/validate-catalog.py`.
5. **Open a PR** and link all relevant issues. Wait for GitHub Actions (`catalog-validate.yml`, `rs-guard-review.yml`).
6. **Address** review feedback with evidence or a documented reason.

## TDD and quality gates

Every skill that produces code should assume the following gates:

- A developer writes a failing test and runs it before implementation.
- `mix format --check-formatted` passes.
- `mix credo --strict` passes.
- `mix test` is green.
- `mix sobelow --config` and `mix deps.audit && mix hex.audit` pass for security-sensitive work.

Playbooks encode these gates as `## HARD-GATE` sections.

## Knowledge base (graphify)

After significant reorganization or new skills, regenerate the navigable knowledge graph if the optional `graphify` skill/CLI is available:

```bash
# Re-extract the whole corpus and rebuild the graph
graphify .

# After extraction, regenerate clusters and the GRAPH_REPORT.md quickly
graphify cluster-only .
```

Outputs are `graphify-out/graph.json`, `graphify-out/GRAPH_REPORT.md`, and `graphify-out/graph.html`. Confirm freshness by comparing the `Built from commit` line in `GRAPH_REPORT.md` with the current `git rev-parse HEAD`, then update `README.md` / `AGENTS.md` with any new cross-cutting skill relationships or stale path references.

## Useful docs

| Doc | Purpose |
|-----|---------|
| `README.md` | Human-facing catalog, install, ecosystem overview |
| `docs/taxonomy.md` | Domain-first folder rules and placement checklist |
| `docs/playbooks.md` | Playbook template and anti-patterns |
| `docs/fcis-engineering-rules.md` | Functional Core, Imperative Shell (FCIS) bar |
| `agents/README.md` | Companion guides and precedence rules |
| `.github/review-prompt.md` | `rs-guard` review criteria |

## Language

All generated artifacts (skills, docs, commit messages, PRs) are in **English** unless a user explicitly requests another language.

## License

MIT. See [LICENSE](LICENSE).
