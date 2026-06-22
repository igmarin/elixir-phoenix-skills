# Code Review Checklist — Elixir/Phoenix

Detailed per-area review criteria. Use with `skills/quality/code-review/SKILL.md`.

---

## Configuration

- [ ] Secrets in `runtime.exs` (never hardcoded in `config.exs`)
- [ ] Verified env vars — `System.get_env!/1` with descriptive errors
- [ ] No adapter config in test env (e.g. Oban in `:inline` mode)
- [ ] Credo `--strict` configured for CI

## Router

- [ ] RESTful resources (shallow nesting, `only`/`except`)
- [ ] API pipeline uses `pipe_through :api` (no session, no CSRF)
- [ ] Named routes used in redirects (`~p"..."` paths)
- [ ] No catch-all routes without rate limiting

## Controllers

- [ ] Thin — delegates to context modules (no `Repo` calls)
- [ ] `before_action` scoped with `when action not in [...]`
- [ ] Strong params via `changeset` or context `cast/4`
- [ ] `action_fallback` used for JSON API error handling
- [ ] Auth checks in every action touching protected resources

## LiveViews

- [ ] `@impl true` on every callback (mount, handle_event, handle_info)
- [ ] Side effects guarded with `if connected?(socket)`
- [ ] All assigns initialized in mount (no `KeyError` on static render)
- [ ] Errors assigned to socket with `put_flash`, never `raise`
- [ ] No `Repo` calls — delegates to context modules
- [ ] Form changesets use `Map.put(:action, :validate)` pattern
- [ ] Streams used for collections over 100 items

## HEEx Templates

- [ ] Function components use `def` (exported), not `defp` for shared usage
- [ ] Slots (`render_slot`) for flexible children instead of hardcoded
- [ ] No business logic in templates — use assigns
- [ ] No `raw/1` on user-supplied content

## Contexts

- [ ] Clear module boundary — context is the sole persistence entry point
- [ ] Functions return `{:ok, result} | {:error, reason}` tuples
- [ ] No context importing another context's internals
- [ ] Public API is documented with `@doc`

## Schemas & Changesets

- [ ] `foreign_key_constraint` and `unique_constraint` in changesets
- [ ] `@required_fields` and `@optional_fields` module attributes
- [ ] `timestamps()` included
- [ ] Virtual fields documented
- [ ] Associations use correct `on_delete` / `on_replace` strategy

## Queries

- [ ] Parameterized queries — `^` for all user input
- [ ] No string interpolation in `fragment` or `Ecto.Adapters.SQL.query`
- [ ] Preloading used to prevent N+1
- [ ] Pagination on collection queries (not `Repo.all`)
- [ ] Composite indexes on multi-field filters

## Migrations

- [ ] Reversible `change/0` (not separate `up`/`down`)
- [ ] Add indexes concurrently for large tables
- [ ] Add columns as nullable, backfill, then enforce NOT NULL
- [ ] Schema changes and data backfills in separate migrations
- [ ] No destructive operations without rollback strategy

## OTP (GenServer, Supervisor)

- [ ] `@impl true` before every callback (init, handle_call, handle_cast)
- [ ] Start link supervision — child properly supervised
- [ ] `handle_continue` for expensive post-init work (not blocking init)
- [ ] No `Process.sleep` — use `:timer.send_after` or `Process.send_after`
- [ ] Clean shutdown — `terminate` callback for cleanup

## Jobs (Oban)

- [ ] Idempotent — checks if work already done before executing
- [ ] Args store IDs, not large data structures
- [ ] Return values: `{:ok, _}` / `{:error, _}` / `{:cancel, _}` / `{:snooze, _}`
- [ ] `max_attempts` and `queue` explicitly set
- [ ] Tested with `perform_job` and `assert_enqueued`

## Tests

- [ ] Failing test written BEFORE implementation (TDD gate)
- [ ] `async: true` only when safe (no shared DB state, no LiveView)
- [ ] Fixtures defined in `test/support/fixtures/` not inline
- [ ] Unauthorized/edge cases tested
- [ ] No hardcoded dates — relative timestamps

## Security

- [ ] No `String.to_atom/1` on user input (atom exhaustion)
- [ ] No `raise` for expected error conditions
- [ ] No secrets in logs (passwords, tokens, API keys)
- [ ] `Plug.Crypto.secure_compare/2` for token comparison
- [ ] Dependency audit — `mix deps.audit && mix hex.audit && mix sobelow`
- [ ] No user-controlled data in redirect paths