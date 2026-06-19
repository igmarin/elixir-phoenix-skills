# Elixir Phoenix Skills

![Elixir Phoenix Skills](https://github.com/user-attachments/assets/placeholder-logo.png)

A curated library of **public Elixir/Phoenix agent skills** that teach AI tools how to write idiomatic Elixir code, test Phoenix applications, and follow production-minded conventions. This repository acts as a **Domain Knowledge Registry** of specialized Elixir & Phoenix AI Skills, consumable by external MCP or CLI runtimes.

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
| [**`elixir-phoenix-skills`**](https://github.com/igmarin/elixir-phoenix-skills) | 32 Elixir/Phoenix skills |
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
> [![Smithery](https://img.shields.io/badge/Smithery-orange)](https://smithery.ai/skills/ismael-marin/elixir-phoenix-skills)

## What are Agent Skills?

Agent Skills are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows. At its core, a skill is a folder containing a `SKILL.md` file. This file includes metadata (`name` and `description`, at minimum) and instructions that tell an agent how to perform a specific task.

This repository follows the Agent Skills standard, meaning you can install the entire catalog of Elixir/Phoenix skills atomically into any compatible agent (e.g., Cursor, Claude Code, Goose, OpenCode, Gemini CLI) using:

```bash
npx skills add igmarin/elixir-phoenix-skills
```

## Who This Is For

| Reader | What you get |
|--------|--------------|
| Elixir developers | Agent instructions for common Elixir/Phoenix work: LiveView, Ecto, OTP, testing, security, and deployment. |
| Team leads | A repeatable workflow that makes AI-assisted Elixir work easier to review because tests, docs, and self-review are part of the process. |
| Junior developers | Step-by-step Elixir workflow guidance that explains what to do next instead of dumping generic code. |
| Senior developers | Opinionated guardrails for TDD, architecture, review, OTP patterns, performance, and production-safe changes. |

## Skill Catalog

The library contains **32 Elixir/Phoenix skills** organized by development concern.

| Category | Skills |
|----------|--------|
| **Core Elixir** | `elixir-essentials`, `otp-essentials`, `typespec-dialyzer` |
| **Phoenix LiveView** | `phoenix-liveview-essentials`, `liveview-streams`, `phoenix-scopes`, `phoenix-liveview-auth` |
| **Database (Ecto)** | `ecto-essentials`, `ecto-changeset-patterns`, `ecto-nested-associations` |
| **Testing** | `testing-essentials`, `property-based-testing`, `benchee-profiling` |
| **Authentication & Authorization** | `phoenix-auth-customization`, `phoenix-authorization-patterns` |
| **Background Jobs** | `oban-essentials`, `broadway-data-pipelines` |
| **Code Quality** | `code-quality`, `credo-config` |
| **Security** | `security-essentials` |
| **Real-time** | `phoenix-pubsub-patterns`, `phoenix-channels-essentials` |
| **APIs** | `phoenix-json-api`, `req-http-client` |
| **Infrastructure** | `deployment-gotchas`, `telemetry-essentials`, `cachex-caching` |
| **Utilities** | `phoenix-uploads`, `swoosh-emails`, `gettext-i18n`, `mix-tasks-generators` |
| **Frameworks** | `ash-framework` |

## Installation

Install skills via skills.sh:

```bash
npx skills add igmarin/elixir-phoenix-skills
```

Or via GitHub CLI (v2.90.0+):

```bash
# Install all skills interactively
gh skill install igmarin/elixir-phoenix-skills

# Install a specific skill
gh skill install igmarin/elixir-phoenix-skills elixir-essentials --scope project
```

## Acknowledgements

This repository adapts content from [elixir-phoenix-guide](https://github.com/j-morgan6/elixir-phoenix-guide) by Joseph Morgan, licensed under MIT. See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) for details.

## Contributing

When contributing skills:

- Keep generated artifacts in English unless a user explicitly asks for another language.
- Follow the established skill format with RULES sections and Integration tables.
- Include good/bad code examples for all major patterns.
- Reference TDD workflow where applicable.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
