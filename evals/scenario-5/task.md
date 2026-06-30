# Production-Ready Phoenix Deployment

## Problem/Feature Description

A fintech startup has built a Phoenix web application called `PayCore` that handles payment processing and user account management. The team has been developing it locally against a development database and is now ready to go live. Their DevOps engineer has flagged several blockers: the application currently has no health monitoring endpoint (making load-balancer integration impossible), secrets are embedded directly in version-controlled config files (a compliance violation), and their deployment runbook still uses `mix` commands that require the full Elixir toolchain installed in production.

The engineering lead has asked you to prepare the production deployment configuration from scratch. The app's module name is `PayCore` and its Ecto repo is `PayCore.Repo`. You should produce all the necessary configuration and source files to make the application production-ready and deployable as an OTP release. The app already has a basic router and application supervisor — you are wiring up the production layer on top of that.

The team also needs a `DEPLOYMENT.md` guide so operations staff can follow the correct sequence when pushing new versions or running database migrations without downtime.

## Output Specification

Produce the following files:

- `config/runtime.exs` — runtime configuration that reads secrets from environment variables. The app needs `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, and `PORT` configured.
- `lib/pay_core/release.ex` — a Release module with functions for running and rolling back Ecto migrations suitable for use in a deployed OTP release (without the Mix tool available).
- `lib/pay_core_web/controllers/health_controller.ex` — a controller that exposes a health check endpoint verifying the database is reachable. Return JSON responses.
- `lib/pay_core/application.ex` — the Application module with a proper supervision tree and telemetry wiring.
- `Dockerfile` — a container image definition using a build and a runtime stage.
- `DEPLOYMENT.md` — a deployment guide explaining environment variable requirements, how to run migrations in production, and the correct startup sequence.

Do not add routes to `router.ex` — just produce the controller and note the route configuration needed in `DEPLOYMENT.md`.
