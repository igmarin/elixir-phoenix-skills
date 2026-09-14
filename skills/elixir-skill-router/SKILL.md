---
name: elixir-skill-router
type: orchestrator
tags: [orchestration]
license: MIT
metadata:
  version: "1.0.0"
  user-invocable: "true"
  dependencies:
    - source: self
      skills:
        - tdd
        - bug-fix
        - quality
        - code-review-playbook
        - setup
        - liveview
        - background-job
        - ecto-migration
        - elixir-essentials
        - phoenix-liveview-essentials
        - testing-essentials
        - ecto-essentials
        - code-review
        - code-quality
        - credo-config
        - oban-essentials
description: >
  Use when an Elixir/Phoenix request spans multiple concerns or the next workflow
  is unclear. Route implementation, bugs, reviews, setup, LiveView, jobs, and
  migrations to the installed playbook and relevant domain skills.
---

# Elixir Skill Router

## HARD-GATE

```text
Non-negotiable: no implementation code until a test exists, runs, and fails for the right reason (feature missing, not config/syntax).
```


## Routing priority

1. **Playbook** when the request is multi-step (TDD, bug fix, quality, setup, LiveView feature, Oban job, migration, PR review).
2. **Atomic skill** when the request is a single domain (Ecto query, channel auth, Credo config).
3. **Code-producing work:** if the next step writes `.ex` or `.exs`, load `elixir-essentials` **together with** the domain skill. It is not only a language-ambiguity fallback.
4. **Ambiguity:** inspect `mix.exs`, `mix.lock`, routes, and nearby code first. Language-only questions use `elixir-essentials`; Phoenix controller/API questions use their domain skills. Select LiveView only when the project and task use LiveView. Ask one scope question if the evidence cannot choose a workflow.
5. **Small bugs:** use `bug-fix` directly with a failing reproduction and minimal fix; a formal PRD is unnecessary. Resolve scope before writing tests for a new feature.

See `assets/skill-map.json` (`mappings`, `defaults`, `disambiguation`).

## Core Process

Prefer **playbooks** for multi-step flows (`tdd`, `bug-fix`, `quality`, `code-review-playbook`, `setup`, `liveview`, `background-job`, `ecto-migration`). Use atomics for single-domain implementation. When implementation writes Elixir, the chain includes `elixir-essentials` so FCIS (pure core, thin edges) is loaded — not only the framework skill.


Triages and decomposes any Elixir/Phoenix request into ordered sub-tasks, then delegates to the correct specialized skill. Identify the matching skill from the catalog below and route to it using the format defined in **Output Style**.

### Core Skills Catalog

The eight most-used skills are listed here. Resolve full catalog names through the installed pack registry (`directory.json` in a source checkout). Read each selected skill before executing its workflow. A missing required skill or resource blocks its dependent step: report the qualified identity, expected path, and installation repair. Continue independent work; disclose missing optional guidance. Never substitute a generic skill for a required missing dependency.

See [`assets/skill-map.json`](assets/skill-map.json) for the full machine-readable trigger→skill routing map used by this orchestrator.

| Skill | Use when... | Notes |
| ----- | ----------- | ----- |
| **elixir-essentials** | Writing any `.ex` or `.exs` file | Default fallback for Elixir language questions |
| **phoenix-liveview-essentials** | Building LiveView pages, handling events, managing assigns | Default fallback for web ambiguity |
| **ecto-essentials** | Database operations, queries, migrations | Default fallback for data layer questions |
| **testing-essentials** | Writing ExUnit tests, setting up fixtures | Entry point for TDD |
| **otp-essentials** | GenServer, Supervisor, Task modules | Concurrency and process patterns |
| **oban-essentials** | Background job processing, job queues | Async work |
| **code-quality** | Refactoring, duplication detection, complexity | Quality gate before PR |
| **security-essentials** | Security review, input validation, XSS/CSRF | Security audit |

### Skill Priority

**Canonical priority rule** — apply this whenever multiple skills could apply:

```text
Priority for code changes: Context and scope → RED → Implementation → Quality → Review.
Read-only reviews begin with review skills; they do not require a new failing test.
```

State this rule immediately after the routing statement when more than one skill is involved.

**Dependency loading:** Load only the selected workflow and applicable domain skills. Routing metadata lists available choices, not instructions to execute every dependency. Continue in the current agent; delegate only when the host supports it and a bounded independent subtask benefits.

### Decomposition Examples

**Example 1 — "Add user notifications: email on job completion + live dashboard counter."**

```text
Next skill: skills/tdd

This spans jobs, email, data, and LiveView. Confirm the existing notification contract, then load testing-essentials for a failing job-completion test.

Priority: Context and scope → RED → elixir-essentials → oban-essentials → ecto-essentials → phoenix-liveview-essentials → code-quality.
```

**Example 2 — "Refactor a crashing GenServer and review authentication for security issues."**

```text
Next skill: skills/security-essentials

Authentication touches security boundaries; audit that first before addressing the GenServer crash.

Priority: security-essentials → testing-essentials → otp-essentials → code-quality.
```

### Common Skill Chains

| Scenario | Skill chain |
|----------|--------------|
| **TDD Feature Loop** *(primary)* | testing-essentials → RED → elixir-essentials + domain skill → credo-config → typespec-dialyzer → PR |
| **Bug fix** | testing-essentials → **[GATE: reproduction test fails]** → elixir-essentials + domain skill → verify passes |
| **Multi-concern review** | security-essentials *(if input/secrets touched)* → code-review (FCIS) → code-quality |
| **New Phoenix feature** | tdd (or liveview when applicable) → testing-essentials → RED → elixir-essentials + relevant Phoenix/Ecto skill → code-quality |
| **Background job** | background-job → testing-essentials → RED → elixir-essentials + oban-essentials → code-quality |

## Output Style

The routing statement MUST be the first substantive line of every response, before any analysis or implementation.

For a single skill:

```text
Next skill: skills/testing-essentials

This is a feature request. I will start by writing a failing test.
```

When multiple skills apply, immediately follow the routing line with one concise priority/chain statement:

```text
Next skill: skills/security-essentials

This pull request contains custom input validation, so we will perform a security review first.

Priority: security-essentials > code-quality; Chain: security-essentials then code-quality.
```

**Language**: Generated artifacts and output MUST be in English unless explicitly requested otherwise.


## When Not to Use

- Simple, single-concern requests that clearly map to one skill (e.g., "write a test for this function" → use `testing-essentials` directly)
- Direct questions about Elixir syntax or Phoenix patterns — route to the specific skill instead
- Cases where the user explicitly names a target skill (e.g., "use the oban-essentials skill")


## Error Recovery

**No skill clearly matches the request:**
- Inspect repository context and use the ambiguity rule above; ask only for a decision the repository cannot answer.

**Request spans multiple concerns:**
- Decompose into ordered sub-tasks and state the priority chain (Context and scope → RED → Implementation → Quality → Review) immediately after the routing line.

**A named skill is missing from the catalog:**
- Resolve the installed catalog; if still missing, report the required dependency and repair step. Do not silently fall back.

**User asks the router to implement directly:**
- Load the chosen workflow and execute it in this agent within the authorized task. Routing is complete only when the workflow has started or a concrete dependency blocker is recorded; a routing statement alone is not task completion.
