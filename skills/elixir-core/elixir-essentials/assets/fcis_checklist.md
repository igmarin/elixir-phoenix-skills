# FCIS checklist (before shipping Elixir code)

- [ ] Business rules live in pure modules (no `Repo` / HTTP / process sends)
- [ ] Edges (`context` shell, LiveView, controller, worker) only fetch, call pure core, persist
- [ ] Fallible APIs return `{:ok, _} | {:error, _}` and chain with `with` when sequential
- [ ] Multi-clause / guards used instead of nested `if`
- [ ] Pipes are linear (no `|> case do`)
- [ ] External maps parsed to struct/changeset before core logic
- [ ] No `String.to_atom/1` on user input; allowlist if atoms required
- [ ] Behaviour callbacks have `@impl true` and stay thin
- [ ] No monad libraries

Full standard: `docs/fcis-engineering-rules.md`.
