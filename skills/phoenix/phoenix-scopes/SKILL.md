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
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Phoenix Scopes

Phoenix 1.8 introduced `Scope` as the new authentication primitive, replacing direct `current_user` access.

## RULES — Follow these with no exceptions

1. **Use bracket access in templates** — `assigns[:current_scope]` prevents crashes when unauthenticated
2. **Test both authenticated and unauthenticated states** — scope-based auth has two distinct code paths
3. **Define `anonymous/0` for the unauthenticated case** — return a Scope with `user: nil`

---

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
end
```

---

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

---

## Safe Template Access

```heex
<%= if assigns[:current_scope] && Scope.authenticated?(@current_scope) do %>
  <p>Welcome, <%= @current_scope.user.email %></p>
  <.link href={~p"/settings"}>Settings</.link>
<% else %>
  <.link href={~p"/login"}>Log in</.link>
<% end %>
```

---

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

---

## Testing Scopes

Always test both authenticated and unauthenticated paths.

### Context / unit test — scope-based filtering

```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.{Blog, Scope}

  describe "list_user_posts/1" do
    test "returns only posts owned by the scope's user" do
      owner = insert(:user)
      other = insert(:user)
      mine = insert(:post, user: owner)
      _theirs = insert(:post, user: other)

      scope = Scope.for_user(owner)
      results = Blog.list_user_posts(scope)

      assert Enum.map(results, & &1.id) == [mine.id]
    end

    test "anonymous scope sees no user-scoped posts" do
      insert(:post)
      assert Blog.list_user_posts(Scope.anonymous()) == []
    end
  end

  describe "Scope predicates" do
    test "authenticated?/1 distinguishes a user from anonymous" do
      assert Scope.authenticated?(Scope.for_user(insert(:user)))
      refute Scope.authenticated?(Scope.anonymous())
    end

    test "can?/2 checks the scope's permission list" do
      scope = %Scope{permissions: [:delete]}
      assert Scope.can?(scope, :delete)
      refute Scope.can?(scope, :publish)
      refute Scope.can?(Scope.anonymous(), :delete)
    end
  end
end
```

### LiveView test — scope-based access control

```elixir
defmodule MyAppWeb.DashboardLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "authenticated user reaches the dashboard", %{conn: conn} do
    conn = log_in_user(conn, insert(:user))

    {:ok, _view, html} = live(conn, ~p"/dashboard")

    assert html =~ "Dashboard"
  end

  test "unauthenticated request is redirected to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
  end
end
```

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| `@current_scope` in templates (crashes when unauthenticated) | `assigns[:current_scope]` bracket access, then guard |
| Assume a scope always has a user | Handle `Scope.anonymous()` (`user: nil`) explicitly |
| Test only the logged-in path | Test both authenticated and unauthenticated flows |
| Pass raw `user` to context functions | Pass the `scope` so auth context travels with the call |
| Scatter permission checks with `if user.role == ...` | Centralize checks in `Scope.can?/2` |
| Leave `@current_user` references after migrating | Replace with `@current_scope.user` (and `assigns[:current_scope]` for optional reads) |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | phoenix-scopes | phoenix-authorization-patterns |
| phoenix-liveview-auth | phoenix-scopes | testing-essentials |

**Companion skills:**
- `phoenix-liveview-auth` — authentication generators and `on_mount` hooks
- `phoenix-authorization-patterns` — role/permission enforcement built on scopes
- `phoenix-liveview-essentials` — LiveView lifecycle the scope assigns plug into
