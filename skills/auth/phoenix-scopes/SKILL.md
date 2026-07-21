---
name: phoenix-scopes
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for Phoenix 1.8+ authentication and authorization. Covers Scope-based authentication
  replacing current_user, including Scope struct definition with roles and permissions, scope
  creation and usage in LiveViews and controllers, safe template access patterns, and step-by-step
  migration from current_user to scopes.
  Use when working with Phoenix 1.8+ authentication, authorization, Scope structs, current_scope,
  scope-based auth, roles, permissions, or migrating from current_user to the new scope-based model.
  Trigger words: Scope, current_scope, scopes, phoenix scopes, role, roles, permission, permissions,
  authorization, authorize, can?, authenticated?, anonymous, on_mount, require_scope.
---

# Phoenix Scopes

## RULES — Follow these with no exceptions

1. **Use bracket access in templates** — `assigns[:current_scope]` prevents crashes when unauthenticated
2. **Test both authenticated and unauthenticated states** — scope-based auth has two distinct code paths
3. **Define `anonymous/0` for the unauthenticated case** — return a Scope with `user: nil`
4. **Pass `scope` to context functions, not a bare `user`** — centralizes authorization and enables tenant/permission checks
5. **Guard mutating events with `Scope.can?/2`** — enforce authorization server-side; never rely on hidden UI controls


## Scope Struct Definition

```elixir
defmodule MyApp.Scope do
  defstruct [:user, :role, :permissions, :tenant]

  def for_user(%MyApp.Accounts.User{} = user) do
    %__MODULE__{
      user: user,
      role: user.role,
      permissions: permissions_for(user.role)
    }
  end

  def anonymous, do: %__MODULE__{user: nil}

  def authenticated?(%__MODULE__{user: nil}), do: false
  def authenticated?(%__MODULE__{}), do: true

  def can?(%__MODULE__{permissions: perms}, action) when is_list(perms), do: action in perms
  def can?(%__MODULE__{}, _action), do: false

  defp permissions_for(:admin), do: [:read, :write, :delete, :manage_users]
  defp permissions_for(:editor), do: [:read, :write]
  defp permissions_for(_), do: []
end
```


## Using Scopes in LiveViews

```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if Scope.authenticated?(scope) do
      {:ok, assign(socket, :posts, Blog.list_user_posts(scope))}
    else
      {:ok, push_navigate(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    if Scope.can?(scope, :delete) do
      # perform delete
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end
end
```


## Safe Template Access

```heex
<%= if assigns[:current_scope] && Scope.authenticated?(@current_scope) do %>
  <p>Welcome, <%= @current_scope.user.email %></p>
  <.link href={~p"/settings"}>Settings</.link>
<% else %>
  <.link href={~p"/login"}>Log in</.link>
<% end %>
```


## Migration Workflow (current_user → Scopes)

1. **Define the Scope struct** — create `MyApp.Scope` with `for_user/1`, `anonymous/0`, `authenticated?/1`, and `can?/2` as shown above.
2. **Update `on_mount` hooks** — replace user assignment with scope assignment (see before/after below). Run `mix test test/my_app_web/live/ --trace` and verify all `on_mount` tests pass before proceeding.
3. **Search and replace `@current_user`** — update all template references to `@current_scope.user`; use `assigns[:current_scope]` for optional access. Run `mix test` and fix any `KeyError` or `FunctionClauseError` failures before continuing.
4. **Update context functions** — pass `scope` instead of `user` to functions that need auth context. Re-run `mix test` to confirm no regressions.
5. **Run the full test suite** — verify both authenticated and unauthenticated flows still work. If failures occur, revert the most recent step, fix the issue, and re-verify before moving forward.

### Before (Phoenix 1.7)

```elixir
def on_mount(:require_authenticated_user, _params, session, socket) do
  case get_user_from_session(session) do
    nil -> {:halt, redirect(socket, to: ~p"/login")}
    user -> {:cont, assign(socket, :current_user, user)}
  end
end
```

### After (Phoenix 1.8)

```elixir
def on_mount(:require_authenticated_user, _params, session, socket) do
  scope = get_scope_from_session(session)

  if Scope.authenticated?(scope) do
    {:cont, assign(socket, :current_scope, scope)}
  else
    {:halt, redirect(socket, to: ~p"/login")}
  end
end
```


## Testing Scopes

Cover both code paths. Context tests assert that scope-based filtering returns only the caller's data; LiveView tests assert scope-based access control.

**Context test — scope-based filtering (`MyApp.DataCase`):**

```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.{Blog, Scope}

  test "list_user_posts/1 returns only posts visible to the scope" do
    owner = insert(:user)
    other = insert(:user)
    own_post = insert(:post, user: owner)
    _hidden = insert(:post, user: other)

    scope = Scope.for_user(owner)

    assert Blog.list_user_posts(scope) == [own_post]
  end
end
```

**LiveView test — scope-based access (`Phoenix.LiveViewTest`):**

```elixir
defmodule MyAppWeb.DashboardLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "shows dashboard content for an authenticated scope", %{conn: conn} do
    conn = log_in_user(conn, insert(:user))
    assert {:ok, _view, html} = live(conn, ~p"/dashboard")
    assert html =~ "Welcome"
  end

  test "redirects to login for an unauthenticated scope", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end
end
```


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Read `@current_scope` directly in a template | Use `assigns[:current_scope]` so unauthenticated renders don't crash |
| Test only the authenticated path | Cover both authenticated and unauthenticated scopes |
| Trust the UI to hide privileged actions | Authorize every mutation server-side with `Scope.can?/2` |
| Pass a bare `user` into context functions | Pass the `scope` so filtering and permissions stay centralized |
| Return `nil` or crash for anonymous callers | Define `anonymous/0` returning a `Scope` with `user: nil` |
| Assume `permissions` is always a list | Pattern-match with an `is_list/1` guard, as `can?/2` does |
| Render a partial page for an unauthenticated scope | Halt in `on_mount` and redirect to the login route |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | phoenix-scopes | phoenix-authorization-patterns |
| phoenix-liveview-auth | phoenix-scopes | testing-essentials |

**Companion skills:** `phoenix-liveview-auth`, `phoenix-authorization-patterns`, `phoenix-auth-customization`, `testing-essentials`.
