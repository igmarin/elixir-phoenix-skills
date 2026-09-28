---
name: phoenix-authentication
type: atomic
description: Use when adding or changing Phoenix authentication, phx.gen.auth integration, LiveView session identity, or migration between current_user and Phoenix 1.8 Scope.
metadata:
  user-invocable: "true"
---

# Phoenix Authentication

Follow the generated authentication code and Phoenix version in the project. Keep authentication (who is signed in) separate from authorization (what that identity may do).

## Version path

- Phoenix 1.7 projects commonly store `user_token` in the session and derive `current_user` for request and LiveView assigns. Preserve this token-to-assign flow unless the task migrates it.
- Phoenix 1.8 projects may use a `Scope` struct. Follow the project's generated `current_scope` plumbing; do not mix both models in one request path without a migration plan.
- Confirm generator output and APIs against `mix.lock` and the checked-out source.

## Change flow

1. Trace router pipelines, session plugs, `on_mount`, generated user schema, and existing tests.
2. Keep password/session verification in the generated auth boundary. Add custom registration fields through a separate migration and explicit changeset allowlists.
3. Derive LiveView identity from the verified session. Never trust a client-supplied user ID or socket param as identity.
4. Test unauthenticated redirect, valid session, invalid session, registration validation, and the changed flow.

Keep authorization rules in policies or `phoenix-authorization-patterns`. Authentication changes require focused tests; schema or session changes need an explicit migration/compatibility checkpoint when they affect existing users.
