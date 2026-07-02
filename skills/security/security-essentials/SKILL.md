---
name: security-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  Provides security guidelines and patterns for Elixir/Phoenix applications. Use when writing
  auth, token handling, redirects, or user input processing, or when any security concern
  arises. Covers atom exhaustion, SQL injection, open redirects, XSS, sensitive data in logs,
  timing attacks, CSRF, and dependency auditing.
  Trigger words: security, atom exhaustion, SQL injection, XSS, open redirect, timing attack, CSRF, Sobelow.

---

# Security Essentials

Use this skill before writing ANY security-sensitive code.

## RULES — Follow these with no exceptions

1. **Never call `String.to_atom/1` on user input** — use `String.to_existing_atom/1` or a whitelist `case` ([Atom Table Exhaustion](#atom-table-exhaustion))
2. **Never interpolate user input into an Ecto `fragment` or raw SQL** — use `^value` bindings, `field/2`, or `$1`/`$2` placeholders ([SQL Injection](#sql-injection))
3. **Never redirect to a user-controlled URL** — use `~p"..."` verified routes or a whitelist of allowed paths ([Open Redirects](#open-redirects))
4. **Never render user content with `raw/1` in HEEx** — let auto-escaping run, or sanitize with `HtmlSanitizeEx` first ([Cross-Site Scripting (XSS)](#cross-site-scripting-xss))
5. **Never log secrets** — log identifiers (`user_id`, `email`), never passwords, tokens, or PII ([Sensitive Data in Logs](#sensitive-data-in-logs))
6. **Always compare tokens with `Plug.Crypto.secure_compare/2`** — never `==`, which leaks length/content via timing ([Timing Attacks](#timing-attacks))
7. **Never disable Phoenix CSRF protection** — keep `:protect_from_forgery` in the browser pipeline and use `<.form>`, not raw `<form>` ([CSRF Protection](#csrf-protection))
8. **Always authorize before returning a record** — verify ownership to prevent parameter tampering and IDOR ([Common Vulnerable Patterns](#common-vulnerable-patterns))
9. **Always run `mix deps.audit && mix hex.audit && mix sobelow` before merge** — fail CI on any HIGH or CRITICAL finding ([Dependency Auditing](#dependency-auditing))

See [`assets/security_checklist.md`](assets/security_checklist.md) for a copy-paste pre-merge checklist covering input validation, auth, secrets, and production hardening.


## Security Review Process

Apply this sequence whenever writing or reviewing security-sensitive code:

1. **Identify attack surface** — list all user inputs, external data sources, and network boundaries
2. **Apply RULES** — implement the feature following all rules above
3. **Run `mix sobelow --router MyAppWeb.Router`** — static analysis on your router and controllers
4. **Run `mix sobelow --private`** — check private functions for vulnerabilities
5. **Review findings by severity** — HIGH severity first, then MEDIUM, then LOW
6. **Fix each finding** — apply the correct pattern from the sections below
7. **Re-run sobelow** — repeat until no issues reported
8. **Run full audit** — `mix deps.audit && mix hex.audit && mix sobelow` before merging
9. **Test manually** — verify with curl/introspection that expected inputs are rejected


## Common Vulnerable Patterns

### Parameter Tampering

❌ **Bad — trusting user input:**
```elixir
def index(conn, %{"status" => status}) do
  users = Repo.all(from u in User, where: u.status == ^status)
  render(conn, "index.html", users: users)
end
```

✅ **Good — validate against allowed values:**
```elixir
@allowedStatuses ~w(active inactive pending)
def index(conn, %{"status" => status}) do
  if status in @allowedStatuses do
    users = Repo.all(from u in User, where: u.status == ^status)
    render(conn, "index.html", users: users)
  else
    put_status(conn, :bad_request)
    |> json(%{error: "Invalid status"})
  end
end
```

### IDOR (Insecure Direct Object Reference)

❌ **Bad — no authorization check:**
```elixir
def show(conn, %{"id" => id}) do
  user = Repo.get!(User, id)
  render(conn, "show.html", user: user)
end
```

✅ **Good — verify ownership:**
```elixir
def show(conn, %{"id" => id}) do
  current_user = conn.assigns.current_user

  case Accounts.get_user_for_current_user(current_user, id) do
    {:ok, user} -> render(conn, "show.html", user: user)
    {:error, :not_found} -> put_status(conn, :not_found) |> json(%{error: "Not found"})
    {:error, :unauthorized} -> put_status(conn, :forbidden) |> json(%{error: "Forbidden"})
  end
end
```


## Atom Table Exhaustion

❌ **Bad — user controls the atom:**
```elixir
role = String.to_atom(params["role"])
```

✅ **Good — whitelist approach:**
```elixir
case params["role"] do
  "admin" -> :admin
  "user" -> :user
  "moderator" -> :moderator
  _ -> {:error, :invalid_role}
end
```


## SQL Injection

Never interpolate strings into Ecto queries; use `^variable` or `$1`/`$2` placeholders.

❌ **Bad — string interpolation in fragment:**
```elixir
# NEVER do this — user can inject SQL through field or value
from(u in User, where: fragment("lower(#{field}) = ?", ^value))
from(u in User, where: fragment("#{condition}", []))
```

❌ **Bad — using unvalidated input in raw SQL:**
```elixir
# NEVER do this — even with ~s() sigil
Ecto.Adapters.SQL.query(Repo, "SELECT * FROM users WHERE name = '#{name}'", [])
```

✅ **Good — parameterized fragment with field/1:**
```elixir
# Safe — field is an atom from schema, value is parameterized
from(u in User, where: fragment("lower(?) = ?", field(u, :status), ^value))
```

✅ **Good — parameterized raw SQL:**
```elixir
Ecto.Adapters.SQL.query(Repo, "SELECT * FROM users WHERE id = $1", [id])
Ecto.Adapters.SQL.query(Repo, "SELECT * FROM users WHERE name = $1 AND status = $2", [name, status])
```

✅ **Good — Ecto query expressions always safe:**
```elixir
# Ecto query expressions are always parameterized
from(u in User, where: u.status == ^status and u.name == ^name)
```


## Open Redirects

Never redirect to user-controlled URLs; use `~p"..."` or a whitelist.

❌ **Bad — user controls redirect destination:**
```elixir
def create(conn, %{"redirect_to" => redirect_to} = params) do
  redirect(conn, to: redirect_to)
end
```

✅ **Good — use verified routes:**
```elixir
redirect(conn, to: ~p"/dashboard")
```

✅ **Good — validate against known paths:**
```elixir
@allowed_redirects ["/dashboard", "/profile", "/settings"]

def create(conn, %{"redirect_to" => redirect_to} = params) do
  if redirect_to in @allowed_redirects do
    redirect(conn, to: redirect_to)
  else
    redirect(conn, to: ~p"/dashboard")
  end
end
```


## Cross-Site Scripting (XSS)

Avoid `raw/1`; sanitize with HtmlSanitizeEx if HTML is required.

❌ **Bad — bypasses escaping:**
```elixir
<%= raw(@user_bio) %>
```

✅ **Good — let Phoenix auto-escape:**
```elixir
<%= @user_bio %>
```

✅ **Good — sanitize if HTML rendering is required:**
```elixir
<%= raw(HtmlSanitizeEx.html5(@user_bio)) %>
```


## Sensitive Data in Logs

❌ **Bad:**
```elixir
Logger.info("User login", email: email, password: password)
Logger.debug("API call", token: api_token, response: resp)
```

✅ **Good:**
```elixir
Logger.info("User login", email: email, user_id: user.id)
Logger.debug("API call", endpoint: url, status: resp.status)
```


## Timing Attacks

Use `Plug.Crypto.secure_compare/2` for token comparison; never `==`.

❌ **Bad — timing-unsafe:**
```elixir
def verify_token(provided_token, stored_token) do
  provided_token == stored_token
end
```

✅ **Good — constant-time comparison:**
```elixir
def verify_token(provided_token, stored_token) do
  Plug.Crypto.secure_compare(provided_token, stored_token)
end
```


## Dependency Auditing

```bash
# Check for known vulnerabilities in dependencies
mix deps.audit

# Verify package checksums against Hex
mix hex.audit

# Static security analysis on your code
mix sobelow --router MyAppWeb.Router

# Run all three before any merge
mix deps.audit && mix hex.audit && mix sobelow --config
```

**Sobelow categories:**

| Category | Severity |
|----------|---------|
| Config (hardcoded secrets, insecure config) | HIGH |
| SQL injection | HIGH |
| Remote Code (unsafe eval/apply) | CRITICAL |
| Cross-Site Scripting | HIGH |
| Function Clobbering | MEDIUM |
| Denial of Service (atom exhaustion) | HIGH |

**Add to CI pipeline:**
```yaml
# .github/workflows/security.yml
- name: Security Audit
  run: |
    mix deps.audit
    mix hex.audit
    mix sobelow --config
```

```elixir
# mix.exs
defp aliases do
  [
    "security.check": ["deps.audit", "hex.audit", "sobelow --config"]
  ]
end
```

**Interpretation:** Any Sobelow finding of HIGH or CRITICAL severity MUST be fixed before merging. LOW findings should be tracked and addressed within 2 sprints.


## CSRF Protection

Never disable Phoenix's built-in CSRF protection.

```elixir
# Phoenix forms automatically include CSRF tokens
# <.form> component handles this — never use raw <form> tags

# API pipeline should NOT include :protect_from_forgery
pipeline :api do
  plug :accepts, ["json"]
  # No :protect_from_forgery — APIs use Bearer tokens instead
end
```


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| `String.to_atom(params["role"])` on user input | Whitelist with a `case`, or use `String.to_existing_atom/1` |
| `fragment("lower(#{field}) = ?", ^value)` | `fragment("lower(?) = ?", field(u, :status), ^value)` |
| `redirect(conn, to: params["redirect_to"])` | `redirect(conn, to: ~p"/dashboard")` or a whitelist |
| `<%= raw(@user_bio) %>` in HEEx | `<%= @user_bio %>`, or `raw(HtmlSanitizeEx.html5(@user_bio))` |
| Compare tokens with `provided == stored` | `Plug.Crypto.secure_compare(provided, stored)` |
| `Logger.info("login", password: pw, token: t)` | Log `user_id` / `email`; never secrets or PII |
| `Repo.get!(User, id)` with no ownership check | Authorize in the context before returning the record |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-auth-customization | security-essentials | phoenix-authorization-patterns |
| ecto-essentials | security-essentials | telemetry-essentials |

**Companion skills:** `phoenix-authorization-patterns`, `phoenix-auth-customization`, `phoenix-liveview-auth`, `code-quality`.
