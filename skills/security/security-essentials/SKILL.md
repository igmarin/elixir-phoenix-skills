---
name: security-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL security-sensitive code. Invoke before writing auth, token handling,
  redirects, or user input processing. Covers atom exhaustion, SQL injection, open redirects,
  XSS, sensitive data in logs, timing attacks, CSRF, and dependency auditing.
  Trigger words: security, atom exhaustion, SQL injection, XSS, open redirect, timing attack, CSRF, Sobelow.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Security Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY security-sensitive code.

## RULES — Follow these with no exceptions

1. **Never use `String.to_atom/1` on user input** — atoms are never garbage collected; user-controlled atoms exhaust the atom table and crash the BEAM VM
2. **Never interpolate strings into `fragment()` or `SQL.query()`** — always use `?` parameters for fragments and `$1` for raw SQL
3. **Never redirect to user-controlled URLs** — validate against a whitelist or use verified routes (`~p"..."`)
4. **Avoid `raw/1` in templates** — Phoenix auto-escapes for a reason; if HTML is required, sanitize first with HtmlSanitizeEx
5. **Never log sensitive data** — passwords, tokens, secrets, API keys must never appear in Logger calls
6. **Use `Plug.Crypto.secure_compare/2` for token comparison** — never `==`, which enables timing attacks
7. **Run dependency audits after changes** — `mix deps.audit`, `mix hex.audit`, and `mix sobelow` catch known vulnerabilities
8. **Add Sobelow to CI** — automate security scanning in your pipeline

---

## Atom Table Exhaustion

The BEAM atom table has a fixed limit (default ~1M atoms) and is **never garbage collected**.

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

---

## SQL Injection

Ecto's query DSL is safe by default. Danger arises with `fragment/1` and raw SQL.

❌ **Bad — string interpolation in fragment:**
```elixir
from(u in User, where: fragment("lower(#{field}) = ?", ^value))
```

✅ **Good — parameterized fragment:**
```elixir
from(u in User, where: fragment("lower(?) = ?", field(u, ^field_name), ^value))
```

✅ **Good — parameterized raw SQL:**
```elixir
Ecto.Adapters.SQL.query(Repo, "SELECT * FROM users WHERE id = $1", [id])
```

---

## Open Redirects

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

---

## Cross-Site Scripting (XSS)

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

---

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

---

## Timing Attacks

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

---

## Dependency Auditing

```bash
# Check for known vulnerabilities
mix deps.audit

# Verify package checksums
mix hex.audit

# Static security analysis
mix sobelow

# All three in sequence
mix deps.audit && mix hex.audit && mix sobelow
```

**Add to CI pipeline:**
```elixir
defp aliases do
  [
    "security.check": ["deps.audit", "hex.audit", "sobelow --config"]
  ]
end
```

---

## CSRF Protection

Phoenix includes CSRF protection by default. Don't disable it.

```elixir
# Phoenix forms automatically include CSRF tokens
# <.form> component handles this — never use raw <form> tags

# API pipeline should NOT include :protect_from_forgery
pipeline :api do
  plug :accepts, ["json"]
  # No :protect_from_forgery — APIs use Bearer tokens instead
end
```

---

## Common Pitfalls

❌ **Don't** use `String.to_atom/1` on user input
❌ **Don't** interpolate strings into SQL fragments
❌ **Don't** redirect to user-controlled URLs
❌ **Don't** use `raw/1` without sanitization
❌ **Don't** log passwords, tokens, or secrets
❌ **Don't** use `==` for token comparison
❌ **Don't** skip dependency audits

✅ **Do** whitelist atom creation from user input
✅ **Do** parameterize all SQL queries
✅ **Do** use verified routes (`~p"..."`) for redirects
✅ **Do** let Phoenix auto-escape templates
✅ **Do** use `Plug.Crypto.secure_compare/2` for secrets
✅ **Do** add Sobelow to CI pipeline

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| elixir-essentials | security-essentials | elixir-essentials |
| ecto-essentials | security-essentials | ecto-essentials |
| phoenix-liveview-auth | security-essentials | phoenix-liveview-auth |
| code-quality | security-essentials | quality (persona) |
| **phoenix-authorization-patterns** | When implementing access control |
| **deployment-gotchas** | When managing secrets in production |
| **credo-config** | When adding security-focused Credo checks |
