# FCIS checklist (before shipping Elixir code)

- [ ] Business rules live in `MyApp.<Context>.<Concept>` (Pricing, Publishing, Policies) — no `Repo` / HTTP / process sends
- [ ] Context modules are the shell: fetch, call core, persist, enqueue
- [ ] Edges (LiveView, controller, worker) only assign/return; no pricing/eligibility/status logic
- [ ] Fallible APIs return `{:ok, _} | {:error, _}` and chain with `with` when sequential
- [ ] Multi-clause / guards used instead of nested `if`
- [ ] Pipes are linear (no `|> case do`; `then/2` ok for a one-off)
- [ ] External maps parsed to struct/changeset before core logic
- [ ] No `String.to_atom/1` on user input; allowlist if atoms required
- [ ] Behaviour callbacks have `@impl true` and stay thin
- [ ] No monad libraries — tagged tuples and `with` only

Full standard: `docs/fcis-engineering-rules.md`.
