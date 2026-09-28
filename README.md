# Elixir Phoenix Skills

A project-scoped set of Elixir, OTP, Ecto, Phoenix, security, operations, and quality skills. Use the `elixir-phoenix` profile from the shared planning pack; install no other language profile in the same project.

`elixir-essentials` is the single language baseline. Use the narrow domain card that matches the change: Ecto, LiveView, auth, jobs, channels, APIs, integrations, or operations. Routine work proceeds with focused evidence; checkpoints are limited to high-risk changes.

## Migration

| Old entry | Use |
|---|---|
| `elixir-skill-router` | shared `work-router` |
| Ecto convention pair | `ecto-essentials` |
| LiveView convention pair or `liveview` | `phoenix-liveview-essentials` |
| `code-review-playbook` | `code-review` |
| `credo-config`, `quality` | `code-quality` |
| `tdd`, `bug-fix`, `setup`, `background-job` | shared router plus the matching domain skill |
| `phoenix-scopes`, `phoenix-auth-customization`, `phoenix-liveview-auth` | `phoenix-authentication`; authorization remains separate |

Run `python3 scripts/validate-catalog.py` and the script unit tests after changes.

See [quality skill consolidation](docs/quality-skills.md) for the current quality boundary.
