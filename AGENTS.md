# Elixir Phoenix skills

- `directory.json` is the registry; keep registered paths valid.
- This is a flat, project-scoped skill pack. Use `profiles.json` in the shared planning repo to install it with the foundation.
- `elixir-essentials` owns the shared Elixir/FCIS baseline. Domain cards contain only domain-specific rules.
- Verify version-dependent behavior against the app's `mix.lock`, generated code, or local dependency source.
- Add focused tests for behavior changes. Blocking checkpoints are for production data, auth/security, deployment, irreversible actions, and unverified external APIs.
- Keep Phoenix 1.7 `current_user` and Phoenix 1.8 `Scope` paths distinct in auth guidance.
- Run `python3 scripts/validate-catalog.py` and `python3 -m unittest discover -s scripts -p 'test_*.py'` after changes.
