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
Context module = shell; MyApp.<Context>.<Concept> = pure core
```

## Repository layout

```text
skills/<name>/SKILL.md   # Flat layout. Groups in skills.sh.json
docs/                    # Cross-cutting design docs
agents/                  # Long-form companion guides (not skills)
scripts/                 # Validation scripts
```

Kinds (`type` in frontmatter): atomic, playbook, orchestrator. Display groups: `skills.sh.json`.

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

A developer should run these before every commit and before opening a PR:

```bash
# 1. Catalog consistency
python3 scripts/validate-catalog.py

# 2. External review of staged changes (dry-run)
git diff --cached --unified=5 > /tmp/staged.diff
./scripts/rs-guard-install.sh
./rs-guard --diff-file /tmp/staged.diff --dry-run
```

`rs-guard` uses the existing `.reviewer.toml` and `.github/review-prompt.md` files for its rules. `scripts/rs-guard-install.sh` downloads the pinned `rs-guard` binary to the repository root; CI runs it as `./rs-guard`. The committed `bin/rs-guard-*` assets are the reference package cache, not the local runtime binary.

## Workflow

1. **Branch** from `main`: `git checkout -b feature/<short-name>`.
2. **Work in small commits** that reference an issue: `Closes #<issue>`.
3. **Stage** changes and run `rs-guard` on them before each commit.
4. **Validate** with `python3 scripts/validate-catalog.py` before opening a PR.
5. **Open a PR** and link all relevant issues. Wait for GitHub Actions (`catalog-validate.yml`, `rs-guard-review.yml`).
6. **Never commit secrets, tokens, or environment-specific URLs** — use redacted examples and `.env.example` files.
7. **Address** review feedback with evidence or a documented reason.

## TDD and quality gates

Every skill that produces code should assume the following gates are verified by a developer:

- A failing test is written and run before implementation.
- `mix format --check-formatted` passes.
- `mix credo --strict` passes.
- `mix test` is green.
- `mix sobelow --config` and `mix deps.audit && mix hex.audit` pass for security-sensitive work.

Playbooks encode these gates as `## HARD-GATE` sections.

## Knowledge base (graphify)

After significant reorganization or new skills, regenerate the navigable knowledge graph if the optional `graphify` skill/CLI is available:

```bash
# Re-extract the whole corpus and rebuild the graph
graphify extract . --backend deepseek --no-cluster

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

## Code intelligence

Use these tools before dumping whole files or grepping the tree.

1. If `.codegraph/` exists, run `codegraph explore "<symbol or question>"` (or the CodeGraph MCP tools).
2. If `graphify-out/graph.json` exists, use Graphify (`graphify explain`, `graphify path`, or the Graphify MCP).
3. For a whole-repo pack, run `repomix` using `repomix.config.json`. Do not commit `repomix-output.*`.
4. Regenerate Graphify with `graphify extract . --backend deepseek --no-cluster` (DeepSeek is the global LLM). Rust workspaces also pass `--cargo`.
