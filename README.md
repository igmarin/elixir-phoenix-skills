# Elixir Phoenix Skills

![Elixir Phoenix Skills](https://github.com/user-attachments/assets/ac5da537-5062-4a67-a8a3-114129bc101a)

A curated library of **public Elixir/Phoenix agent skills** — 38 atomic skills, 7 playbooks, and 1 entry-point orchestrator that teach AI tools how to write idiomatic Elixir code, test Phoenix applications, and follow production-minded conventions.

The project is built around core Elixir principles:

```text
Pattern matching over conditionals → Let it crash → Pipes for transformations → with for fallible operations
```

These principles are encoded directly into the skills, so agents produce idiomatic Elixir code that follows the BEAM philosophy.

## Part of the AI Skill Ecosystem

This repo is one of 6 in a composable AI skill ecosystem:

| Repo | Role |
|------|------|
| [`ruby-core-skills`](https://github.com/igmarin/ruby-core-skills) | 15 shared Ruby skills + process discipline |
| [`rails-agent-skills`](https://github.com/igmarin/rails-agent-skills) | 28 atomic skills + 9 personas |
| [**`elixir-phoenix-skills`**](https://github.com/igmarin/elixir-phoenix-skills) | 38 atomic skills + 7 playbooks + 1 orchestrator |
| [`hanakai-yaku`](https://github.com/igmarin/hanakai-yaku) | 35 Hanami/dry-rb skills + 10 personas |
| [`agnostic-planning-skills`](https://github.com/igmarin/agnostic-planning-skills) | 10 planning skills + 4 personas |
| [`agent-mcp-runtime`](https://github.com/igmarin/agent-mcp-runtime) | Rust CLI runtime (pack resolution, MCP) |

See the [Ecosystem Overview](https://github.com/igmarin/agent-mcp-runtime/blob/main/docs/ecosystem.md) for the full architecture.

> Supported agent environments
>
> [![ChatGPT](https://custom-icon-badges.demolab.com/badge/ChatGPT-74aa9c?logo=openai&logoColor=white)](#)
> [![Claude](https://img.shields.io/badge/Claude-D97757?logo=claude&logoColor=fff)](#)
> [![Cursor](https://img.shields.io/badge/Cursor-000000?logo=cursor)](#)
> [![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-000?logo=githubcopilot&logoColor=fff)](#)
> [![Google Gemini](https://img.shields.io/badge/Google%20Gemini-886FBF?logo=googlegemini&logoColor=fff)](#)
> [![OpenCode](https://img.shields.io/badge/OpenCode-4285F4?style=for-the-badge&logoColor=white)](#)
> [![Windsurf](https://img.shields.io/badge/Windsurf-0B100F?logo=windsurf&logoColor=fff)](#)

> Official distribution
>
> [![GitHub tag](https://img.shields.io/github/v/tag/igmarin/elixir-phoenix-skills?label=release)](https://github.com/igmarin/elixir-phoenix-skills/tags)
> [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
> [![skills.sh](https://skills.sh/b/igmarin/elixir-phoenix-skills)](https://skills.sh/igmarin/elixir-phoenix-skills)

## What are Agent Skills?

Agent Skills are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows. At its core, a skill is a folder containing a `SKILL.md` file with metadata, instructions, and optionally `assets/`. This repository follows the Agent Skills standard:

```bash
npx skills add igmarin/elixir-phoenix-skills
```

## Who This Is For

| Reader | What you get |
|--------|--------------|
| Elixir developers | Agent instructions for common Elixir/Phoenix work: LiveView, Ecto, OTP, testing, security, and deployment. |
| Team leads | A repeatable workflow that makes AI-assisted Elixir work easier to review — tests, docs, and self-review are part of the process. |
| Junior developers | Step-by-step Elixir workflow guidance that explains what to do next instead of dumping generic code. |
| Senior developers | Opinionated guardrails for TDD, architecture, review, OTP patterns, performance, and production-safe changes. |

## Skill Catalog

The library contains **46 skills total** — 38 atomic skills, 7 playbooks, and 1 orchestrator — organized by category.

### Atomic Skills

| Category | Skills | Path |
|----------|--------|------|
| **Elixir Core** | `elixir-essentials`, `otp-essentials`, `typespec-dialyzer` | `skills/elixir-core/` |
| **Phoenix** | `phoenix-liveview-essentials`, `liveview-streams`, `phoenix-channels-essentials`, `phoenix-json-api`, `phoenix-pubsub-patterns`, `phoenix-uploads`, `apply-phoenix-liveview-conventions`, `apply-phoenix-controller-conventions` | `skills/phoenix/` |
| **Database** | `ecto-essentials`, `ecto-changeset-patterns`, `ecto-nested-associations`, `apply-ecto-conventions` | `skills/database/` |
| **Testing** | `testing-essentials`, `property-based-testing` | `skills/testing/` |
| **Performance** | `benchee-profiling`, `telemetry-essentials` | `skills/performance/` |
| **Auth** | `phoenix-liveview-auth`, `phoenix-auth-customization`, `phoenix-authorization-patterns`, `phoenix-scopes` | `skills/auth/` |
| **Infrastructure** | `oban-essentials`, `broadway-data-pipelines`, `deployment-gotchas`, `cachex-caching` | `skills/infrastructure/` |
| **Quality** | `code-quality`, `credo-config`, `code-review`, `refactor-code`, `respond-to-review` | `skills/quality/` |
| **Security** | `security-essentials` | `skills/security/` |
| **Integrations** | `req-http-client`, `swoosh-emails`, `gettext-i18n` | `skills/integrations/` |
| **Tooling** | `mix-tasks-generators` | `skills/tooling/` |
| **Frameworks** | `ash-framework` | `skills/frameworks/` |

### Playbooks (Workflow Orchestration)

Playbooks orchestrate multiple atomic skills into end-to-end workflows with hard gates, phases, and human-in-the-loop checkpoints:

| Playbook | Path | Purpose |
|----------|------|---------|
| **tdd** | `skills/playbooks/tdd/` | Full TDD cycle with test-first discipline |
| **quality** | `skills/playbooks/quality/` | Code quality loop before PR |
| **setup** | `skills/playbooks/setup/` | Project setup and CI/CD configuration |
| **bug-fix** | `skills/playbooks/bug-fix/` | Bug fixing with reproduction tests |
| **background-job** | `skills/playbooks/background-job/` | Robust Oban job implementation |
| **liveview** | `skills/playbooks/liveview/` | Full LiveView feature development |
| **ecto-migration** | `skills/playbooks/ecto-migration/` | Safe migrations with expand-contract |

Entry routing lives under **orchestration** (`skills/orchestration/elixir-skill-router/`), not under playbooks.

### Assets

Key skills include `assets/` with templates, checklists, and code snippets:

| Skill | Assets |
|-------|--------|
| `testing-essentials` | `spec_templates.md`, `tdd_checklist.md` |
| `code-quality` | `refactoring_checklist.md` |
| `code-review` | `checklist.md` |
| `security-essentials` | `security_checklist.md` |
| `phoenix-liveview-essentials` | `liveview_test_template.md`, `component_test_template.md` |
| `phoenix-channels-essentials` | `channel_test_template.md` |
| `phoenix-liveview-auth` | `on_mount_template.ex` |
| `ecto-essentials` | `migration_checklist.md`, `changeset_snippets.ex` |
| `oban-essentials` | `oban_job_template.ex`, `oban_testing_checklist.md` |
| `broadway-data-pipelines` | `broadway_pipeline_template.ex` |
| `telemetry-essentials` | `telemetry_handler_snippets.ex` |
| `req-http-client` | `req_client_snippets.ex` |
| `swoosh-emails` | `mailer_template.ex` |
| `elixir-skill-router` | `skill-map.json` |

## How Skills Chain Together

Skills are designed to compose. A typical workflow chains from entry to quality gate:

```
elixir-skill-router → tdd (playbook) → quality (playbook) → PR
```

### Common Chains

| Workflow | Skill chain |
|----------|-------------|
| **New feature** | `elixir-skill-router` → `tdd` → `quality` |
| **Bug fix** | `elixir-skill-router` → `bug-fix` → `quality` |
| **New LiveView page** | `liveview` → `tdd` → `quality` |
| **Background job** | `background-job` → `quality` |
| **Database change** | `ecto-migration` → `setup` |
| **Before PR** | `quality` (standalone) |
| **Project bootstrap** | `setup` → `tdd` |

### Per-skill Chaining

Every skill includes an Integration table showing predecessor and successor skills:

```markdown
| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| elixir-essentials | testing-essentials | code-quality |
```


## Documentation standards

Contributor and agent standards for this library:

| Doc | Purpose |
|-----|---------|
| [docs/taxonomy.md](docs/taxonomy.md) | Domain-first folders, placement rules, migration matrix |
| [docs/fcis-engineering-rules.md](docs/fcis-engineering-rules.md) | Pragmatic FCIS (pure core, tagged tuples, thin edges) |
| [docs/playbooks.md](docs/playbooks.md) | Playbook template: phases, hard gates, HITL, mermaid |

## Installation

```bash
# Install all skills
npx skills add igmarin/elixir-phoenix-skills

# Or via GitHub CLI (v2.90.0+)
gh skill install igmarin/elixir-phoenix-skills

# Install a specific playbook
gh skill install igmarin/elixir-phoenix-skills tdd --scope project
```

## Acknowledgements

This repository adapts content from [elixir-phoenix-guide](https://github.com/j-morgan6/elixir-phoenix-guide) by Joseph Morgan, licensed under MIT. See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) for details.

## Contributing

When contributing skills:

- Keep generated artifacts in English unless a user explicitly asks for another language.
- Follow the established skill format with RULES sections and 3-column Integration tables.
- Include good/bad code examples for all major patterns.
- Add `assets/` with templates, checklists, or snippets when the skill benefits from reusable artifacts.
- Playbooks must include phases, hard gates, error recovery, and an output style section.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
