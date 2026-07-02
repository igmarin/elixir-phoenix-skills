# Rate Limiter for a Multi-Tenant API Gateway

## Problem/Feature Description

Your team maintains an API gateway that fronts several internal microservices. As the platform has grown, abuse from a handful of high-volume tenants has started to degrade response times for everyone else. Leadership wants a per-tenant request rate limiter rolled out before the next release cycle.

The rate limiter must handle thousands of read queries per second (each incoming request checks whether the caller is within their quota) while writes — incrementing a counter, resetting a window — happen far less frequently. The team has agreed that the implementation should be a standalone OTP module that the gateway supervisor can manage; no database or external process store is required. The limiter needs to run safely in production, so process naming must be safe for dynamic tenant registrations over the life of the application.

An engineering lead has flagged that the last OTP module the team shipped caused a slow startup problem because it blocked in `init/1`. The new implementation must not repeat that mistake. Any log output must be machine-readable so the ops team can pipe it into their log aggregation system.

## Output Specification

Deliver the following files:

- `lib/rate_limiter.ex` — the main `RateLimiter` module implementing the rate limiter logic
- `lib/rate_limiter/application.ex` — an `Application` module that starts the necessary supervisor tree so the rate limiter is properly supervised
- `IMPLEMENTATION.md` — a short design document (plain Markdown) explaining:
  - Why you chose your storage strategy for reads vs. writes
  - How process naming is handled and why
  - Any notable OTP patterns applied (e.g. how init returns and why)

Do not include a Mix project file (`mix.exs`) or test files — the grader will review the source files and design document only. Keep total output small (under 5 files).
