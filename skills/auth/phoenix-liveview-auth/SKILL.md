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

---

# Phoenix LiveView Authentication

Use this skill before writing ANY `on_mount` hook or LiveView auth code.

> **Requires** `phoenix-scopes` for Scope struct setup. See `phoenix-authorization-patterns` for access control after authentication, and `phoenix-liveview-essentials` before writing any LiveView module.

## RULES — Follow these with no exceptions

1. **Use `on_mount` callbacks** — never check auth in `mount/3` directly
2. **`:halt` must redirect with a flash message** — never silently drop the connection
3. **Define `on_mount` hooks once, reference via `live_session` in router** — never duplicate auth logic across LiveView modules
4. **Resolve import conflicts with `import Phoenix.Controller, except: [redirect: 2, put_flash: 3]`** — so LiveView's `redirect/2` and `put_flash/3` take precedence
5. **Use bracket access `assigns[:current_scope]` in templates that can render unauthenticated** — never `@current_scope` directly (raises `KeyError`)
6. **Add `@impl true` to every LiveView callback** — including a `mount/3` that reads `socket.assigns.current_scope.user`


## Implementation Workflow

1. **Define `on_mount` hooks** in `UserAuth` with import conflict resolution; verify with `mix compile`
2. **Add `live_session` blocks** to the router referencing those hooks; verify with `mix phx.routes`
3. **Run auth tests** with `mix test test/my_app_web/live/` and assert redirect tuples match expected paths; if tests fail, check session config and verify `Accounts.get_user_by_session_token/1` returns the correct user
4. **Add template guards** using bracket access for optional assigns


## on_mount Authentication Pattern

```elixir
defmodule MyAppWeb.UserAuth do
  use MyAppWeb, :verified_routes
  import Phoenix.LiveView
  # Exclude Phoenix.Controller's redirect/2 and put_flash/3 so LiveView's versions take precedence
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

See [`assets/on_mount_template.ex`](assets/on_mount_template.ex) for copy-paste `on_mount` templates (Phoenix 1.7 `current_user`, Phoenix 1.8+ `Scope`, and role-based variants).


## Router Integration

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  live_session :mount_current_scope,
    on_mount: [{MyAppWeb.UserAuth, :mount_current_scope}] do
    scope "/", MyAppWeb do
      pipe_through :browser
      live "/", HomeLive.Index
    end
  end

  live_session :require_authenticated_user,
    on_mount: [{MyAppWeb.UserAuth, :require_authenticated_user}] do
    scope "/", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user]
      live "/dashboard", DashboardLive.Index
      live "/settings", SettingsLive.Index
    end
  end

  live_session :redirect_if_authenticated,
    on_mount: [{MyAppWeb.UserAuth, :redirect_if_authenticated}] do
    scope "/", MyAppWeb do
      pipe_through [:browser, :redirect_if_user]
      live "/users/register", UserRegistrationLive
      live "/users/log_in", UserLoginLive
    end
  end
end
```


## Template Access

```elixir
@impl true
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  {:ok, assign(socket, :posts, Posts.list_posts(user))}
end
```

```heex
<%# Use assigns[:current_scope] (bracket access), not @current_scope — avoids KeyError on unauthenticated sockets %>
<%= if assigns[:current_scope] && @current_scope.user do %>
  <p>Welcome, <%= @current_scope.user.email %></p>
<% end %>
```


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


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Check auth inside `mount/3` with a manual token lookup | Use an `on_mount` hook wired through `live_session` |
| Return `{:halt, socket}` with no redirect or flash | `redirect(socket, to: ~p"/users/log_in")` plus a `put_flash/3` |
| `import Phoenix.Controller` unfiltered (shadows LiveView helpers) | `import Phoenix.Controller, except: [redirect: 2, put_flash: 3]` |
| Reference `@current_scope` in templates that render for guests | Use `assigns[:current_scope] && @current_scope.user` (bracket access) |
| Repeat the auth check in every LiveView module | Group routes under a `live_session` with the shared hook |
| Omit `@impl true` on LiveView callbacks | Add `@impl true` above `mount/3`, `handle_event/3`, etc. |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-scopes | phoenix-liveview-auth | phoenix-authorization-patterns |
| phoenix-liveview-essentials | phoenix-liveview-auth | phoenix-auth-customization |

**Companion skills:** `phoenix-scopes`, `phoenix-authorization-patterns`, `testing-essentials`
