---
name: setup
type: persona
tags: [personas]
license: MIT
description: >
  Complete Elixir/Phoenix project setup loop with hard gates: verify Elixir/Erlang versions match .tool-versions, Hex and Rebar installed, database connection successful, all env vars loaded → configure CI/CD pipeline with testing and linting → validate end-to-end with mix deps.get, mix ecto.create, mix ecto.migrate, mix test, and write SETUP_CHECKLIST.md; phases context/onboarding→CI/CD configuration→environment validation. Use when starting a new Phoenix project, running `mix phx.new`, configuring mix.exs, setting up a development environment, or wiring up CI/CD for an Elixir project. Trigger: setup project, new Phoenix app, configure CI/CD, dev environment setup, mix phx.new, mix.exs setup, Elixir project bootstrap.
---

### Phase 1: Context & Onboarding

**Inline setup (always applicable):**
```bash
# Verify Elixir/Erlang versions match .tool-versions
elixir --version
mix deps.get
mix ecto.create
mix ecto.migrate
mix test --seed 0
mix compile --warnings-as-errors
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

**If environment check FAILS:** Fix the failing item above before proceeding to Phase 2.


### Phase 2: CI/CD Configuration

**Proceed only after environment check passes.**

#### `.github/workflows/ci.yml`

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
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

#### `.github/workflows/cd.yml`

```yaml
name: CD
on:
  push:
    branches: [main]
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
      - run: <DEPLOY_CLI>   # e.g. flyctl deploy, gigalixir releases deploy

  deploy-production:
    runs-on: ubuntu-latest
    environment: production
    needs: deploy-staging
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - uses: erlef/setup-beam@5304e04ea2b355f03681464e683d92e3b2f18451
        with:
          elixir-version: "1.17.x"
          otp-version: "27.x"
      - run: mix deps.get
      - run: mix ecto.migrate
        env:
          MIX_ENV: prod
          DATABASE_URL: ${{ secrets.PRODUCTION_DATABASE_URL }}
      - run: <DEPLOY_CLI>   # same CLI as staging, targeting production
```

> Fill in `<DEPLOY_CLI>` with your deployment command (e.g., `flyctl deploy`, `gigalixir releases deploy`, or a custom Docker push). Replace secret names to match your repository settings.


### Phase 3: Environment Validation

**Verify everything works end-to-end:**

Confirm every item in the Phase 1 HARD GATE checklist is still fully passing, then additionally verify:

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


## Output Style

When completing project setup, output a **Setup Report** using this template:

```
Environment:  Elixir <ver> ✓/✗ | OTP <ver> ✓/✗ | DB <ver> <status> | Env vars: <source>
Dependencies: deps.get <N> ✓/✗ | ecto.create ✓/✗ | ecto.migrate <N> ✓/✗ | mix test <N passed>/<N failed> ✓/✗
CI/CD:        ci.yml ✓/✗ | cd.yml ✓/✗ | SHAs pinned ✓/✗ | Pipeline order confirmed ✓/✗
Validation:   Server port <port> ✓/✗ | Full test suite ✓/✗ | SETUP_CHECKLIST.md written ✓/✗
```


## Error Recovery

**System Modification Approval Gate (CRITICAL):**
Before suggesting any action that modifies the host system: explain why it is needed, ask for explicit user confirmation, and only proceed if the user approves.

**Non-obvious failure pointers:**
- **Elixir version mismatch** → check `.tool-versions` and ensure the correct version is active via `asdf` or `mise` before retrying
- **Database connection fails** → run `pg_isready` to confirm PostgreSQL is running; check `config/dev.exs` credentials and create any missing role
- **Mix compile fails** → run `mix deps.get` and `mix deps.compile`; check for missing system libraries
- **CI actions use mutable tags** → resolve SHA with `git ls-remote`, replace `@v4` with `@<full-sha>` in workflow files
