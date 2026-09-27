---
name: elixir-essentials
type: atomic
description: Use for Elixir language and OTP work without a narrower domain skill. This is the shared baseline for the elixir-phoenix profile.
metadata:
  user-invocable: "true"
---

# Elixir Essentials

Use the project's Elixir version, formatter, dependencies, and established module boundaries. Verify library behavior against the checked-out version before relying on an API.

- Prefer pattern matching and `with` for expected branches; use pipes for clear transformations.
- Keep pure decisions and transformations separate from IO, Repo, HTTP, process, and framework effects.
- Parse external maps, strings, and messages at the boundary into validated structs or changesets.
- Return tagged tuples for expected failures. Let unexpected failures reach supervision or error reporting.
- Use processes for state or concurrency, not as a default wrapper around pure functions.
- Add typespecs when they clarify a public boundary or support Dialyzer; do not annotate trivial private code mechanically.
- Add a focused test for changed behavior. Run the project's formatter and relevant tests; add Credo, Sobelow, or dependency audit checks when the change touches those concerns.

Domain skills in this profile inherit this baseline. Keep their instructions limited to domain-specific behavior.
