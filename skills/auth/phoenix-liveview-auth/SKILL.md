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

## RULES — Follow these with no exceptions

1. **Always use `on_mount` callbacks for LiveView auth** — never check auth in `mount/3` directly; `on_mount` runs before mount and centralizes auth logic
2. **Use `mount_current_scope/2` to extract scope from session** — never access session tokens manually or parse session data in LiveViews
3. **Handle both `:cont` and `:halt` returns from `on_mount`** — `:halt` must redirect with a flash message, never silently drop the connection
4. **Resolve import conflicts explicitly** — `Phoenix.Controller` and `Phoenix.LiveView` both export `redirect/2` and `put_flash/3`; use `except:` to avoid ambiguity
5. **Use bracket access `assigns[:current_scope]` in templates** — dot access `@current_scope` crashes on nil when user is not authenticated
6. **Test auth redirects by asserting `{:error, {:redirect, %{to: path}}}`** — don't test auth by checking rendered content; verify the redirect tuple from `live/2`
7. **Define `on_mount` hooks once, reference via `live_session` in router** — never duplicate auth logic across LiveView modules

---

## on_mount Authentication Pattern

```elixir
defmodule MyAppWeb.UserAuth do
  use MyAppWeb, :verified_routes
  import Phoenix.LiveView
  import Phoenix.Controller, except: [redirect: 2, put_flash: 3]

  # Called by live_session :require_authenticated_user
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

  # Called by live_session :redirect_if_authenticated
  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  # Called by live_session :mount_current_scope (public pages)
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

  # Public pages — scope is mounted but not required
  live_session :mount_current_scope,
    on_mount: [{MyAppWeb.UserAuth, :mount_current_scope}] do
    scope "/", MyAppWeb do
      pipe_through :browser

      live "/", HomeLive.Index
    end
  end

  # Authenticated pages
  live_session :require_authenticated_user,
    on_mount: [{MyAppWeb.UserAuth, :require_authenticated_user}] do
    scope "/", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user]

      live "/dashboard", DashboardLive.Index
      live "/settings", SettingsLive.Index
    end
  end

  # Guest-only pages
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

## Import Conflict Resolution

`Phoenix.Controller` and `Phoenix.LiveView` both export `redirect/2` and `put_flash/3`.

❌ **Bad — compile error or wrong function called:**
```elixir
import Phoenix.Controller
import Phoenix.LiveView
```

✅ **Good — explicitly exclude conflicting functions:**
```elixir
import Phoenix.LiveView
import Phoenix.Controller, except: [redirect: 2, put_flash: 3]
```

---

## current_scope vs current_user

Phoenix 1.8+ uses `Scope` structs instead of raw `current_user`.

```elixir
# Phoenix 1.8+ pattern — Scope struct
defmodule MyApp.Scope do
  defstruct [:user]
end

# In LiveView — access user through scope
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  {:ok, assign(socket, :posts, Posts.list_posts(user))}
end

# In templates — use bracket access for safety
<%= if assigns[:current_scope] && @current_scope.user do %>
  <p>Welcome, <%= @current_scope.user.email %></p>
<% end %>
```

---

## Safe Template Access

Always use bracket access for assigns that may not exist:

❌ **Bad — crashes if current_scope is nil:**
```elixir
<%= @current_scope.user.email %>
```

✅ **Good — safe bracket access:**
```elixir
<%= if assigns[:current_scope] && @current_scope.user do %>
  <%= @current_scope.user.email %>
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

❌ **Don't** check auth in `mount/3` — use `on_mount` hooks
❌ **Don't** access session tokens manually in LiveViews
❌ **Don't** use `@current_scope` in templates without nil check
❌ **Don't** duplicate auth logic across LiveView modules
❌ **Don't** forget to handle `:halt` with a redirect and flash message

✅ **Do** define `on_mount` hooks once and reuse via `live_session`
✅ **Do** use `mount_current_scope/2` for session extraction
✅ **Do** resolve import conflicts with `except:`
✅ **Do** test auth by asserting redirect tuples
✅ **Do** use bracket access for optional assigns in templates

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-scopes** | When implementing Phoenix 1.8+ Scope-based auth |
| **phoenix-authorization-patterns** | After authentication, for access control |
| **phoenix-liveview-essentials** | Before writing any LiveView module |
| **testing-essentials** | Before writing auth tests |
