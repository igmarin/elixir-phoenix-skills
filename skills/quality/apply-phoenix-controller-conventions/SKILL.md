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
2. **Use `before_action` for authentication and resource loading** — chain with `:skip` opt-out pattern
3. **Always validate and authorize** every action that touches access-controlled resources
4. **Use `FallbackController` for JSON API error handling** — never inline `error/2` or catch-all `case` clauses in actions
5. **Match content pipeline to format** — API pipeline (no session, no CSRF) for JSON; browser pipeline for HTML
6. **Use `conn.assigns` for passing data between plugs and actions** — never use `Process` dictionaries
7. **Never interpolate user input into redirect paths** — use `~p"..."` paths for verified routes

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
  Accounts.update_user(user, user_params)  # User could send any field
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

The context module validates fields:
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

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| Business logic in controller (e.g., `Repo.insert` inline) | Delegate to context module (`Accounts.create_user`) |
| `before_action` without `:skip` on login/exempt actions | Use `plug :auth when action not in [:index, :show]` |
| `redirect(to: user_provided_url)` | Use `~p"..."` verified path or `url` helpers |
| JSON error handling in each action | Use `action_fallback FallbackController` |
| `json(conn, ...)` in browser pipeline | Use `pipe_through :api` for JSON endpoints |
| Process dictionaries for passing data between plugs | Use `conn.assigns` |

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