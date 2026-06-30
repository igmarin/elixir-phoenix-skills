---
name: apply-phoenix-controller-conventions
type: atomic
tags: [atomic, quality]
license: MIT
description: >
  Use when writing new controller code in Phoenix applications. Enforces consistent
  patterns for RESTful routing, plug pipeline ordering, action methods, strong
  parameters, content negotiation, fallback controllers, and error handling.
  Covers resource routing, before_action, conn.assigns, json/html rendering,
  and authentication plugs.
  Trigger words: phoenix controller conventions, controller patterns, phoenix
  router, plug pipeline, before_action, fallback controller, strong params,
  phoenix routes, action fallback.

# Apply Phoenix Controller Conventions

Use this skill when writing new Phoenix controller modules or modifying existing controller code to ensure consistent, idiomatic patterns.

**Precondition:** Invoke `phoenix-liveview-essentials` before this skill if the feature uses LiveView; for traditional request/response, use this skill directly.

---

## Quick Reference

| Pattern | Convention |
|---------|------------|
| Routes | `resources` for RESTful; `scope` for grouping |
| Controllers | Thin — delegate business logic to contexts |
| before_action | For auth, resource loading; return `conn` |
| Strong params | Use `changeset` validation or `cast/4` in context |
| Content type | Pipeline `:browser` for HTML; `:api` for JSON |
| Error handling | Use `FallbackController` for structured errors |
| Auth plugs | Include pipeline plugs; skip with `:skip` option |

---

## RULES — Follow these with no exceptions

1. **Keep controllers thin** — never put business logic in controllers; delegate to context modules
2. **Use `plug` guards for authentication and resource loading** — chain with `when action not in [...]` opt-out pattern
3. **Always validate and authorize** every action that touches access-controlled resources
4. **Use `FallbackController` for JSON API error handling** — never inline catch-all `case` clauses in actions
5. **Match content pipeline to format** — API pipeline (no session, no CSRF) for JSON; browser pipeline for HTML
6. **Use `conn.assigns` for passing data between plugs and actions** — never use `Process` dictionaries
7. **Never interpolate user input into redirect paths** — use `~p"..."` paths for verified routes

---

## Routing Conventions

✅ **RESTful resources with shallow nesting:**
```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  resources "/users", UserController do
    resources "/posts", PostController, only: [:index, :show], shallow: true
  end

  resources "/posts", PostController, only: [:index, :show]
end
```

**Checkpoint:** Run `mix phx.routes` to verify routes resolve correctly and there are no unintended deep-nesting paths.

---

## Plug Pipeline Ordering

✅ **`plug` guards with opt-out, auth at controller level:**
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  plug :require_authenticated_user when action not in [:index, :show]
  plug :load_user when action in [:edit, :update]

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  def edit(conn, _params) do
    render(conn, :edit, user: conn.assigns.user)
  end

  def update(conn, %{"user" => user_params}) do
    case Accounts.update_user(conn.assigns.user, user_params) do
      {:ok, user} -> redirect(conn, to: ~p"/users/#{user}")
      {:error, changeset} -> render(conn, :edit, user: conn.assigns.user, changeset: changeset)
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp load_user(conn, _opts) do
    user = Accounts.get_user!(conn.params["id"])
    assign(conn, :user, user)
  end
end
```

**Checkpoint:** Confirm plug ordering with `mix phx.routes` and verify that exempt actions (e.g., `:index`, `:show`) do not trigger auth plugs in integration tests.

---

## Action Patterns

✅ **Thin controller delegating to context:**
```elixir
def create(conn, %{"user" => user_params}) do
  case Accounts.register_user(user_params) do
    {:ok, user} ->
      conn
      |> put_flash(:info, "User created")
      |> redirect(to: ~p"/users/#{user}")

    {:error, changeset} ->
      render(conn, :new, changeset: changeset)
  end
end
```

For JSON API endpoints, use `with` + `FallbackController` instead of `case`:

```elixir
def create(conn, %{"user" => user_params}) do
  with {:ok, user} <- Accounts.register_user(user_params) do
    conn
    |> put_status(:created)
    |> render(:show, user: user)
  end
end
```

---

## Strong Parameters / Params Validation

Validation belongs in the context, not the controller. The controller passes params through unchanged (see the `update/2` example in [Plug Pipeline Ordering](#plug-pipeline-ordering)), while the context enforces permitted fields:

```elixir
# Context — enforce permitted fields via changeset
def update_user(user, attrs) do
  user
  |> User.changeset(attrs)  # cast/2 only permits declared fields
  |> Repo.update()
end
```

---

## Content Negotiation

✅ **API pipeline for JSON, browser pipeline for HTML:**
```elixir
# Router
scope "/api", MyAppWeb do
  pipe_through :api
  resources "/users", Api.UserController, only: [:index, :show]
end

# Phoenix API pipeline (router.ex)
pipeline :api do
  plug :accepts, ["json"]
end

# Controller — use render/3, not json/2, so views handle serialisation
def index(conn, _params) do
  users = Accounts.list_users()
  render(conn, :index, users: users)
end
```

**Checkpoint:** Confirm the correct pipeline is applied by inspecting `mix phx.routes` output and checking that API routes lack `:fetch_session` and `:protect_from_forgery` plugs.

---

## FallbackController for JSON APIs

✅ **`action_fallback` + centralised `FallbackController`:**
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  action_fallback MyAppWeb.FallbackController

  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.get_user(id) do
      render(conn, :show, user: user)
    end
  end
end

defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Forbidden"})
  end
end
```

**Checkpoint:** Run `mix test test/controllers/` after wiring up `FallbackController` to confirm each expected error tuple (`{:error, :not_found}`, `{:error, :unauthorized}`) is matched and returns the correct HTTP status.

---

## Error Handling — Browser

✅ **Pattern match on expected errors; redirect with flash:**
```elixir
def show(conn, %{"id" => id}) do
  case Accounts.get_user(id) do
    {:ok, user} ->
      render(conn, :show, user: user)

    {:error, :not_found} ->
      conn
      |> put_flash(:error, "User not found")
      |> redirect(to: ~p"/users")
      |> halt()
  end
end
```

Avoid `get_user!/1` (raises) for user-triggered lookups; reserve bang variants for developer errors where a crash is the correct signal.

**Checkpoint:** Verify error paths in browser tests by asserting flash messages and redirect targets.

---

## Common Pitfalls

| ❌ Wrong | ✅ Correct |
|----------|----------|
| Business logic in controller (`Repo.insert` inline) | Delegate to context module (`Accounts.create_user`) |
| Auth plug without action guard on public actions | Use `plug :auth when action not in [:index, :show]` |
| `redirect(to: user_provided_url)` | Use `~p"..."` verified path helpers |
| JSON error handling duplicated in each action | Use `action_fallback FallbackController` |
| `pipe_through :browser` for JSON endpoints | Use `pipe_through :api` for JSON scopes |
| `Process` dictionary for inter-plug data | Use `conn.assigns` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | apply-phoenix-controller-conventions | code-quality |
| phoenix-json-api | apply-phoenix-controller-conventions | testing-essentials |

**Companion skills:**
- `phoenix-json-api` — RESTful API controller patterns and versioning
- `phoenix-liveview-essentials` — LiveView for interactive pages
- `phoenix-scopes` — authentication and authorization setup
- `phoenix-uploads` — file upload in controller actions
