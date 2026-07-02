---
name: phoenix-liveview-auth
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL LiveView authentication work. Invoke before writing on_mount hooks,
  auth plugs for LiveViews, or session handling in LiveView modules.
  Covers on_mount patterns, current_scope, import conflict resolution, safe template access,
  and testing auth redirects.
  Trigger words: on_mount, LiveView auth, current_scope, session, live_session, redirect_if_authenticated.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix LiveView Authentication

> **Requires** `phoenix-scopes` for Scope struct setup. See `phoenix-authorization-patterns` for access control after authentication, and `phoenix-liveview-essentials` before writing any LiveView module.

## RULES — Follow these with no exceptions

1. **Always use `on_mount` callbacks for LiveView auth** — never check auth in `mount/3` directly
2. **Use `mount_current_scope/2` to extract scope from session** — never access session tokens manually
3. **`:halt` must redirect with a flash message** — never silently drop the connection
4. **Define `on_mount` hooks once, reference via `live_session` in router** — never duplicate auth logic across LiveView modules

---

## Implementation Workflow

1. **Define `on_mount` hooks** in `UserAuth` with import conflict resolution; verify the module compiles cleanly with `mix compile`
2. **Add `live_session` blocks** to the router referencing those hooks; verify routes are registered correctly with `mix phx.routes`
3. **Run auth tests** with `mix test test/my_app_web/live/` and assert redirect tuples match expected paths; if tests fail, check session config and verify `Accounts.get_user_by_session_token/1` returns the correct user
4. **Add template guards** using bracket access for optional assigns

---

## on_mount Authentication Pattern

```elixir
defmodule MyAppWeb.UserAuth do
  use MyAppWeb, :verified_routes
  import Phoenix.LiveView
  import Phoenix.Controller, except: [redirect: 2, put_flash: 3]

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      if user = find_user_from_session(session) do
        %Scope{user: user}
      end
    end)
  end

  defp find_user_from_session(%{"user_token" => token}) do
    Accounts.get_user_by_session_token(token)
  end

  defp find_user_from_session(_session), do: nil
end
```

See [`assets/on_mount_template.ex`](assets/on_mount_template.ex) for copy-paste `on_mount` templates (Phoenix 1.7 `current_user`, 1.8+ Scope, and role-based hooks).

---

## Router Integration

Define one `live_session` block per auth mode, each referencing the matching `on_mount` hook from `UserAuth`.

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # Mounts current scope for public pages — never redirects, user may be nil
  live_session :mount_current_scope,
    on_mount: [{MyAppWeb.UserAuth, :mount_current_scope}] do
    scope "/", MyAppWeb do
      pipe_through :browser
      live "/", PageLive.Home
      live "/posts", PostLive.Index
    end
  end

  # Requires authentication — redirects unauthenticated users to the log-in page
  live_session :require_authenticated_user,
    on_mount: [{MyAppWeb.UserAuth, :require_authenticated_user}] do
    scope "/", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user]
      live "/dashboard", DashboardLive.Index
      live "/settings", SettingsLive.Index
    end
  end

  # Redirects already-authenticated users away from login/register pages
  live_session :redirect_if_authenticated,
    on_mount: [{MyAppWeb.UserAuth, :redirect_if_authenticated}] do
    scope "/", MyAppWeb do
      pipe_through :browser
      live "/users/log_in", UserLive.Login
      live "/users/register", UserLive.Registration
    end
  end
end
```

---

## Template Access

After an `on_mount` hook populates `current_scope`, read the user in `mount/3` and assign it for the template that follows:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok, assign(socket, :current_user, socket.assigns.current_scope.user)}
end
```

In templates, use bracket access for optional assigns to avoid `KeyError` when `current_scope` may be absent:

```heex
<%= if assigns[:current_scope] && @current_scope.user do %>
  <p>Welcome, <%= @current_scope.user.email %></p>
<% end %>
```

---

## Testing LiveView Auth

```elixir
describe "require_authenticated_user" do
  test "redirects if not logged in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} =
             live(conn, ~p"/dashboard")
  end

  test "renders page when authenticated", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _lv, html} = live(conn, ~p"/dashboard")
    assert html =~ "Dashboard"
  end
end

describe "redirect_if_authenticated" do
  test "redirects if already logged in", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/"}}} =
             live(conn, ~p"/users/log_in")
  end
end
```

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Check auth with an ad-hoc `if` inside `mount/3` | Use `on_mount` hooks referenced by `live_session` |
| `{:halt, socket}` with no redirect or flash | Redirect with a `put_flash` message before halting |
| Read `@current_scope.user` directly in templates | Guard with `assigns[:current_scope] && @current_scope.user` |
| Duplicate auth logic across every LiveView | Define hooks once in `UserAuth`, wire them in the router |
| Pull `user_token` out of the session by hand | Build the scope via `mount_current_scope/2` |
| `import Phoenix.Controller` without excluding conflicts | `import Phoenix.Controller, except: [redirect: 2, put_flash: 3]` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-scopes | phoenix-liveview-auth | phoenix-authorization-patterns |
| phoenix-liveview-essentials | phoenix-liveview-auth | phoenix-auth-customization |

**Companion skills:**
- `phoenix-scopes` — Scope struct setup (required predecessor)
- `phoenix-authorization-patterns` — access control after authentication
- `phoenix-liveview-essentials` — LiveView callback lifecycle reference
- `phoenix-auth-customization` — extending `phx.gen.auth` with custom fields
