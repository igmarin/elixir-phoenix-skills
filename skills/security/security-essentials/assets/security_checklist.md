# Elixir Security Checklist

## Input Validation
- [ ] All user input validated at the boundary (changesets, controller params)
- [ ] `String.to_atom/1` NEVER used on user input (use `String.to_existing_atom/1`)
- [ ] File uploads validated for type, size, and sanitized filenames
- [ ] Query parameters cast to correct types (Ecto schema or manual casting)

## SQL Injection
- [ ] All Ecto queries use parameterized values (never string interpolation)
- [ ] No raw SQL with `Ecto.Adapters.SQL.query!` using interpolated user input
- [ ] If raw SQL is unavoidable, use parameterized queries with `Ecto.Query.API.fragment`

```elixir
# SAFE: Ecto automatically parameterizes
Repo.all(from u in User, where: u.name == ^user_input)

# DANGEROUS: String interpolation
Repo.query!("SELECT * FROM users WHERE name = '#{user_input}'")

# SAFE: Parameterized fragment
Repo.all(from u in User, where: fragment("lower(name) = lower(?)", ^user_input))
```

## XSS Prevention
- [ ] Phoenix templates auto-escape by default — verify no `raw/1` on user content
- [ ] LiveView `~H` sigil auto-escapes — only `Phoenix.HTML.raw/1` bypasses
- [ ] JSON API responses use `Phoenix.json_library` (safe by default)
- [ ] Never use `raw/1` with user-supplied content

## CSRF Protection
- [ ] Phoenix includes CSRF tokens in forms and LiveView sockets by default
- [ ] API endpoints authenticate via token/header, not session cookies
- [ ] `plug :protect_from_forgery` present in browser pipeline

## Authentication
- [ ] Passwords hashed with `bcrypt_elixir` or `argon2_elixir` (never stored plaintext)
- [ ] Session secrets use `Phoenix.Token` or `Plug.Session` with strong signing secret
- [ ] `SECRET_KEY_BASE` generated via `mix phx.gen.secret` (not hardcoded)
- [ ] Token expiration enforced for password reset and session tokens
- [ ] Rate limiting on login attempts (via Oban or Hammer)

## Authorization
- [ ] Every LiveView mount and controller action checks authorization
- [ ] Context modules enforce ownership (user can only access their own data)
- [ ] Admin-only actions have explicit role checks

```elixir
# Context-level authorization
def delete_post(user, post_id) do
  post = Repo.get!(Post, post_id)

  if post.user_id == user.id do
    Repo.delete(post)
  else
    {:error, :unauthorized}
  end
end
```

## Secrets & Configuration
- [ ] No secrets in source code (use `System.fetch_env!/1` or runtime config)
- [ ] Production secrets come from environment variables or secret manager
- [ ] `config/runtime.exs` reads secrets at runtime, not compile time
- [ ] `.env` files in `.gitignore`
- [ ] Mix tasks that touch external services use `Application.get_env/2` at runtime

## Dependencies
- [ ] `mix hex.audit` run regularly to check for known vulnerabilities
- [ ] Dependencies pinned to known versions (not git branches in production)
- [ ] Review dependency licenses for compliance

## Production
- [ ] `MIX_ENV=prod` used for all production deploys
- [ ] Database URL uses TLS/SSL (`?ssl=true` on connection string)
- [ ] Cookie `secure: true` and `http_only: true` in production
- [ ] Debug routes disabled in production (`config :phoenix, :serve_endpoints, false`)
- [ ] Request logging excludes sensitive params (`filter_parameters` in endpoint config)
