# Oban Testing Checklist

Use `Oban.Testing` with `testing: :inline` (or `:manual`) in `config/test.exs`.
Verify each item before considering a worker done.

## Setup
- [ ] `config :my_app, Oban, testing: :inline` set in `config/test.exs`
- [ ] Test module has `use MyApp.DataCase, async: true`
- [ ] Test module has `use Oban.Testing, repo: MyApp.Repo`
- [ ] Worker aliased at the top of the test module

## Enqueue Assertions
- [ ] `assert_enqueued(worker: MyWorker, args: %{...})` after the enqueuing call
- [ ] `refute_enqueued(...)` for paths that must NOT enqueue
- [ ] Unique/dedupe behavior asserted (enqueue twice, assert one job)

## Execution (`perform_job/2`)
- [ ] Uses `perform_job(MyWorker, %{...})` — never `MyWorker.perform/1` directly
- [ ] Success path asserts `{:ok, _}`
- [ ] Retryable failure path asserts `{:error, _}`
- [ ] Permanent failure path asserts `{:cancel, _}`
- [ ] Snooze path (if any) asserts `{:snooze, _}`

## Idempotency
- [ ] Running `perform_job/2` twice produces no duplicate side effects
- [ ] Guard (`already_sent`/`processed_at`) is covered by a test

## Quality Gate
- [ ] All return paths covered (success, error, cancel)
- [ ] Args in tests use realistic keys (string keys as stored in the DB)
- [ ] `mix test` passes with the worker's queue configured
