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
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Apply Phoenix Controller Conventions

Use this skill when writing new Phoenix controller modules or modifying existing controller code to ensure consistent, idiomatic patterns.

**Precondition:** Invoke `phoenix-liveview-essentials` before this skill if the feature uses LiveView; for traditional request/response, use this skill directly.

---

## Workflow: Creating a New Controller

1. **Define route** — add to `router.ex` using `resources` or `scope`; verify with `mix phx.routes`
2. **Create controller module** — thin module, delegate all business logic to a context
3. **Add auth/load plugs** — declare `plug` directives at the top of the controller; verify with `mix compile --warnings-as-errors`
4. **Implement actions** — pattern-match params, call context, render or redirect
5. **Wire error handling** — use `action_fallback` for JSON APIs; pattern-match for browser; verify with `mix test test/controllers/`

---

## RULES — Follow these with no exceptions

1. **Keep controllers thin** — delegate all business logic to context modules; never inline `Repo` calls or email sending in an action
2. **Cast and validate params in a context `changeset/2`** — never pass raw `params` straight to `Repo`
3. **Declare auth/resource plugs at the controller top** — scope with `when action in/not in [...]`; every plug must return `conn`
4. **Use `action_fallback` + a `FallbackController`** for JSON APIs; pattern-match on context results for browser actions
5. **Pick the right pipeline** — `:browser` (session + CSRF) for HTML, `:api` (no session, no CSRF) for JSON
6. **Always use `~p"..."` verified route sigils** for redirects and links — never interpolate user input into paths
7. **Share state through `conn.assigns`** between plugs and actions — never the process dictionary

---

## Quick Reference

| Pattern | Convention |
|---------|------------|
| Controllers | **Thin** — delegate all business logic to context modules; never inline Repo calls or email sending |
| Routes | `resources` for RESTful; `scope` for grouping; shallow nesting preferred |
| Plugs (`before_action`) | Auth and resource loading only; use `when action in/not in` guards; return `conn` |
| Strong params | Validate and cast in context via `changeset/2`; never pass raw params to Repo |
| Content type | Pipeline `:browser` for HTML (session + CSRF); `:api` for JSON (no session, no CSRF) |
| Error handling | `FallbackController` + `action_fallback` for JSON APIs; pattern-match for browser |
| Auth plugs | Declare at controller level; opt-out with `when action not in [...]` |
| Redirects | Always use `~p"..."` verified route sigils — never interpolate user input |
| Conn sharing | Use `conn.assigns` between plugs and actions — never `Process` dictionaries |

---

## Routing Conventions

❌ **Bad — deep nesting, no scoping:**
```elixir
scope "/" do
  get "/users/:user_id/posts/:post_id/comments", CommentController, :show
  get "/users/:user_id/posts", PostController, :index
  get "/users", UserController, :index
end
```

✅ **Good — RESTful resources with shallow nesting:**
```elixir
scope "/", MyAppWeb do
  pipe_through :browser

  resources "/users", UserController do
    resources "/posts", PostController, only: [:index, :show], shallow: true
  end

  resources "/posts", PostController, only: [:index, :show]
end
```

**Checkpoint:** Run `mix phx.routes` to verify routes resolve correctly.

---

## Plug Pipeline Ordering

❌ **Bad — auth plug after action, before_action leaking across unrelated actions:**
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  def edit(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, :edit, user: user)
  end

  def update(conn, %{"id" => id}) do
    # No auth check...
  end
end
```

✅ **Good — before_action with :skip opt-out, auth at controller level:**
```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  plug :require_authenticated_user when action not in [:index, :show]
  plug :load_user when action in [:edit, :update]

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, :index, users: users)
  end

  def edit(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    render(conn, :edit, user: user)
  end

  def update(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Accounts.update_user(user, %{}) do
      {:ok, user} -> redirect(conn, to: ~p"/users/#{user}")
      {:error, changeset} -> render(conn, :edit, user: user, changeset: changeset)
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

**Checkpoint:** Run `mix compile --warnings-as-errors` to confirm no unused plug warnings, then `mix test test/controllers/` to verify auth behaviour.

---

## Action Patterns

❌ **Bad — business logic in controller, inline error handling, no fallback:**
```elixir
def create(conn, %{"user" => user_params}) do
  changeset = User.changeset(%User{}, user_params)

  case MyApp.Repo.insert(changeset) do
    {:ok, user} ->
      token = MyApp.Accounts.generate_token()
      MyApp.Accounts.send_welcome_email(user.email, token)
      conn
      |> put_flash(:info, "User created")
      |> redirect(to: ~p"/users/#{user}")

    {:error, changeset} ->
      render(conn, :new, changeset: changeset)
  end
end
```

✅ **Good — thin controller, delegate to context, let it crash or use fallback:**
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

For JSON API endpoints, use a FallbackController instead:

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

❌ **Bad — mass assignment, no params validation:**
```elixir
def update(conn, %{"user" => user_params}) do
  user = Accounts.get_user!(conn.params["id"])
  Accounts.update_user(user, user_params)
end
```

✅ **Good — cast params in context or changeset:**
```elixir
def update(conn, %{"user" => user_params}) do
  user = Accounts.get_user!(conn.params["id"])

  case Accounts.update_user(user, user_params) do
    {:ok, user} ->
      redirect(conn, to: ~p"/users/#{user}")

    {:error, changeset} ->
      render(conn, :edit, changeset: changeset)
  end
end
```

```elixir
def update_user(user, attrs) do
  user
  |> User.changeset(attrs)  # cast/2 only permits expected fields
  |> Repo.update()
end
```

---

## Content Negotiation

❌ **Bad — browser pipeline for JSON endpoint, inline JSON generation:**
```elixir
# Router
scope "/api", MyAppWeb do
  pipe_through :browser

  resources "/users", Api.UserController
end

# Controller
def index(conn, _params) do
  users = Accounts.list_users()
  json(conn, %{data: users})
end
```

✅ **Good — API pipeline, proper rendering:**
```elixir
# Router
scope "/api", MyAppWeb do
  pipe_through :api

  resources "/users", Api.UserController, only: [:index, :show]
end

# Controller
def index(conn, _params) do
  users = Accounts.list_users()
  render(conn, :index, users: users)
end
```

```elixir
# Phoenix API pipeline (in router.ex)
pipeline :api do
  plug :accepts, ["json"]
end
```

---

## FallbackController for JSON APIs

❌ **Bad — inline error handling in every action:**
```elixir
def show(conn, %{"id" => id}) do
  case Accounts.get_user(id) do
    {:ok, user} -> render(conn, :show, user: user)
    {:error, :not_found} -> put_status(conn, :not_found) |> json(%{error: "Not found"})
    {:error, _} -> put_status(conn, :internal_server_error) |> json(%{error: "Server error"})
  end
end
```

✅ **Good — action_fallback + FallbackController:**
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

**Checkpoint:** Run `mix test test/controllers/` to confirm fallback clauses handle all expected error tuples.

---

## Error Handling — Browser

❌ **Bad — raising on expected errors:**
```elixir
def show(conn, %{"id" => id}) do
  user = Accounts.get_user!(id)  # Raises if not found
  render(conn, :show, user: user)
end
```

✅ **Good — pattern match and render:**
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

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Put business logic or `Repo` calls inside an action | Delegate to a context function and keep the action thin |
| Pass raw `params` to `Repo.insert/1` | Cast/validate through a context `changeset/2` first |
| `raise` on an expected-missing record in a browser action | Pattern-match `{:error, :not_found}` and `put_flash` + `redirect` |
| Duplicate error rendering in every JSON action | Centralize with `action_fallback MyAppWeb.FallbackController` |
| Interpolate user input into a redirect path string | Use the `~p"..."` verified route sigil |
| Reuse the `:browser` pipeline for a JSON endpoint | Route JSON through the `:api` pipeline (no session/CSRF) |
| Load the current user with a raw plug returning a value | Write a plug that assigns to `conn.assigns` and returns `conn` |

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
