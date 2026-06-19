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

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY `on_mount` hook or LiveView auth code.

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

---

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

---

## Template Access

```elixir
# In LiveView — access user through scope
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  {:ok, assign(socket, :posts, Posts.list_posts(user))}
end

# In templates — use bracket access for optional assigns
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
