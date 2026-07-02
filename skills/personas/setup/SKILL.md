---
name: setup
type: persona
tags: [personas]
license: MIT
description: >
  Complete Elixir/Phoenix project setup loop with hard gates: verify Elixir/Erlang versions match .tool-versions, Hex and Rebar installed, database connection successful, all env vars loaded → configure CI/CD pipeline with testing and linting → validate end-to-end with mix deps.get, mix ecto.create, mix ecto.migrate, mix test, and write SETUP_CHECKLIST.md; phases context/onboarding→CI/CD configuration→environment validation. Use when starting a new Phoenix project, running `mix phx.new`, configuring mix.exs, setting up a development environment, or wiring up CI/CD for an Elixir project. Trigger: setup project, new Phoenix app, configure CI/CD, dev environment setup, mix phx.new, mix.exs setup, Elixir project bootstrap.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when starting new Phoenix project, setting up dev environment, or configuring CI/CD"
  phases: "Phase 1: Context & Onboarding, Phase 2: CI/CD Configuration, Phase 3: Environment Validation"
  hard_gates: "Environment Check, CI/CD Configuration, Environment Validation"
  dependencies:
    - source: self
      skills: [elixir-essentials, phoenix-liveview-essentials, ecto-essentials, testing-essentials]
  keywords: elixir, phoenix, setup, onboarding, ci/cd, agent, devops, configuration
---
# Setup Persona

Orchestrates complete project setup, CI/CD configuration, and environment validation across three gated phases.

## Agent Phases

### Phase 1: Context & Onboarding

**Inline setup (always applicable):**
```bash
# Verify Elixir/Erlang versions match .tool-versions
elixir --version
# Install dependencies
mix deps.get
# Create the database
mix ecto.create
# Run migrations
mix ecto.migrate
# Confirm test runner is operational
mix test --seed 0
# Compile to catch early errors
mix compile --warnings-as-errors
# Copy env example if missing
cp .env.example .env 2>/dev/null || true
```

**HARD GATE — Environment Check** (all items must pass before Phase 2):
- [ ] Elixir version correct (check `.tool-versions` or `elixir_buildpack.config`)
- [ ] Erlang/OTP version correct
- [ ] Hex and Rebar installed (`mix local.hex`, `mix local.rebar`)
- [ ] Database connection successful (`mix ecto.create` succeeds or DB already exists)
- [ ] Runtime env vars are available from the shell or `.env`
- [ ] Phoenix secret key base configured (`SECRET_KEY_BASE` env var)
- [ ] All external CI actions pinned to immutable commit SHAs (never mutable tags like @v4)

**If gate fails:** Fix the failing item above before proceeding to Phase 2.

---

### Phase 2: CI/CD Configuration

**Proceed only after environment check passes.**

**Shared action versions** (used in every job below — match your `.tool-versions`):

| Action | Pinned SHA |
|--------|------------|
| `actions/checkout` | `34e114876b0b11c390a56381ad16ebd13914f8d5` |
| `erlef/setup-beam` | `5304e04ea2b355f03681464e683d92e3b2f18451` |
| `elixir-version` | `"1.17.x"` |
| `otp-version` | `"27.x"` |

1. **Configure CI pipeline** — write to `.github/workflows/ci.yml`.

```yaml
steps:
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
  - uses: erlef/setup-beam@5304e04ea2b355f03681464e683d92e3b2f18451
    with:
      elixir-version: "1.17.x"
      otp-version: "27.x"
  - run: mix deps.get
  - run: mix compile --warnings-as-errors
  - run: mix format --check-formatted
  - run: mix credo --strict
  - run: mix test --cover
  - run: mix dialyzer
```

2. **Configure CD pipeline** — write to `.github/workflows/cd.yml`.

   Fill in `DEPLOY_CLI` (e.g., `flyctl`, `gigalixir`, custom Docker) and the appropriate secret names. Use the same action SHAs and versions from the shared table above.

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - uses: erlef/setup-beam@5304e04ea2b355f03681464e683d92e3b2f18451
        with:
          elixir-version: "1.17.x"
          otp-version: "27.x"
      - run: mix deps.get
      - run: mix ecto.migrate
        env:
          MIX_ENV: staging
          DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
      - run: <DEPLOY_CLI>
```

   Duplicate `deploy-staging` as `deploy-production` with `environment: production`, `needs: deploy-staging`, `MIX_ENV: prod`, and `DATABASE_URL: ${{ secrets.PRODUCTION_DATABASE_URL }}`.

---

### Phase 3: Environment Validation

**Verify everything works end-to-end:**

Confirm Phase 1 gates still pass, then additionally verify:

```bash
# Start Phoenix server
mix phx.server

# CI simulation (if using act)
act push
```

**Write `SETUP_CHECKLIST.md`** recording the final state of all Phase 1 HARD GATE items plus:
- [ ] CI configured
- [ ] Secrets configured
- [ ] Phoenix server starts and serves pages

---

## Output Style

When completing project setup, output a **Setup Report** with the following required fields:

- **Environment**: Elixir version (matched against `.tool-versions`), Erlang/OTP version, database version and connection status, env vars source.
- **Dependencies**: results of `mix deps.get`, `mix ecto.create`, `mix ecto.migrate`, `mix test --seed 0` (with counts).
- **CI/CD**: paths to generated workflow files, SHA-pinning confirmation, pipeline step order.
- **Validation**: Phoenix server start status (port), full test suite result, `SETUP_CHECKLIST.md` written confirmation.

Use ✓/✗ symbols and include counts (e.g., number of deps, migrations, tests) for each item.

---

## Error Recovery

**System Modification Approval Gate (CRITICAL):**
Before suggesting ANY action that modifies the host system:
1. Explain why it is needed
2. Ask the user for explicit confirmation
3. Only proceed if the user approves

**Non-obvious failure pointers:**
- **Elixir version mismatch** → check `.tool-versions` and ensure the correct version is active via `asdf` or `mise` before retrying
- **Database connection fails** → run `pg_isready` to confirm PostgreSQL is running; check `config/dev.exs` credentials and create any missing role
- **Mix compile fails** → run `mix deps.get` and `mix deps.compile`; check for missing system libraries
- **CI actions use mutable tags** → resolve SHA with `git ls-remote`, replace `@v4` with `@<full-sha>` in workflow files

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|--------------|----------|
| elixir-skill-router | setup | tdd |
| None (standalone) | setup | quality |
| mix phx.new | setup | liveview |
