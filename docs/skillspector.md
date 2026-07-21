# SkillSpector notes

This library is **markdown agent skills**, not executable install hooks. Scanners such as SkillSpector may still flag teaching examples.

## Policy

| Severity | Policy |
|----------|--------|
| Real secrets, live hosts, exfiltration | Must fix immediately |
| Educational HTTP / SQL / auth patterns | Prefer reword to config-driven or descriptive form |
| Residual false positives after hygiene | Document here; do **not** commit scanner `report.md` |

Local scan artifacts (`report.md`, `review-result.txt`, `rs-guard-metrics.json`) stay **gitignored**.

## Current residual risk posture

As of the #37 hygiene pass the library was previously scanned **SAFE / LOW**. Findings addressed in skills:

1. **`req-http-client` (E1)** — examples use `Application.fetch_env!(:my_app, :api_base_url)` instead of hard-coded hosts.
2. **`deployment-gotchas` (EA2)** — health-check guidance is descriptive pattern language, not an agent imperative to run SQL.
3. **`phoenix-channels-essentials` (EA2)** — join authorization described as API contract (`{:ok, socket}` vs `{:error, ...}`), not autonomous execution.

Re-run SkillSpector locally after skill edits if you maintain a marketplace badge:

```bash
# example — use your installed SkillSpector CLI
skillspector scan skills/   # writes gitignored report.md
```

## Related

- Closed #25 (older CRITICAL false positives)
- Issue #37 (MEDIUM residual tracking)
- FCIS standard: [fcis-engineering-rules.md](fcis-engineering-rules.md)
