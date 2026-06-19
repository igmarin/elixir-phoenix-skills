---
name: phoenix-scopes
type: atomic
license: MIT
description: >
  MANDATORY for Phoenix 1.8+ authentication work. Invoke before implementing auth with Scope structs.
  Covers the new Scope-based authentication replacing current_user, scope creation, scope usage in
  LiveViews and controllers, and migration from current_user to scopes.
  Trigger words: Scope, current_scope, Phoenix 1.8, authentication, authorization, scope struct.
metadata:
  version: 1.0.0
---

# Phoenix Scopes

Phoenix 1.8 introduced `Scope` as the new authentication primitive, replacing direct `current_user` access.

## RULES — Follow these with no exceptions

1. **Use Scope structs instead of raw `current_user`** — scopes wrap the user and can carry additional context
2. **Access user through `socket.assigns.current_scope.user`** — never use `@current_user` directly in Phoenix 1.8+
3. **Use bracket access in templates** — `assigns[:current_scope]` prevents crashes when unauthenticated
4. **Extend scopes with additional context** — add roles, permissions, or tenant info to the scope
5. **Migrate existing `current_user` code to use scopes** — update `on_mount` hooks and templates
6. **Test scope-based auth thoroughly** — test both authenticated and unauthenticated states

---

## Scope Struct Definition

```elixir
defmodule MyApp.Scope do
  @moduledoc """
  Represents the current authentication scope.
  Wraps the user and can carry additional context like roles or tenant info.
  """

  defstruct [:user, :role, :tenant]

  @type t :: %__MODULE__{
    user: MyApp.Accounts.User.t() | nil,
    role: atom() | nil,
    tenant: String.t() | nil
  }

  @doc """
  Creates a scope for an authenticated user.
  """
  def for_user(%MyApp.Accounts.User{} = user) do
    %__MODULE__{user: user, role: user.role}
  end

  @doc """
  Creates an anonymous scope.
  """
  def anonymous do
    %__MODULE__{user: nil}
  end

  @doc """
  Returns true if the scope represents an authenticated user.
  """
  def authenticated?(%__MODULE__{user: nil}), do: false
  def authenticated?(%__MODULE__{}), do: true
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
      posts = Blog.list_user_posts(scope)
      {:ok, assign(socket, :posts, posts)}
    else
      {:ok, push_navigate(socket, to: ~p"/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Dashboard</h1>
    <p>Welcome, <%= @current_scope.user.email %></p>

    <%= for post <- @posts do %>
      <div><%= post.title %></div>
    <% end %>
    """
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

## Extending Scopes with Roles

```elixir
defmodule MyApp.Scope do
  defstruct [:user, :role, :permissions]

  def for_user(%MyApp.Accounts.User{} = user) do
    %__MODULE__{
      user: user,
      role: user.role,
      permissions: get_permissions(user.role)
    }
  end

  def can?(%__MODULE__{permissions: perms}, action) do
    action in perms
  end

  defp get_permissions(:admin), do: [:read, :write, :delete, :manage_users]
  defp get_permissions(:editor), do: [:read, :write]
  defp get_permissions(:viewer), do: [:read]
end

# Usage in LiveView
def handle_event("delete", %{"id" => id}, socket) do
  scope = socket.assigns.current_scope

  if Scope.can?(scope, :delete) do
    # Perform delete
  else
    {:noreply, put_flash(socket, :error, "Not authorized")}
  end
end
```

---

## Migration from current_user

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

## Common Pitfalls

❌ **Don't** use `@current_user` in Phoenix 1.8+ — use `@current_scope.user`
❌ **Don't** access `@current_scope` without nil check in templates
❌ **Don't** put sensitive data directly in the scope — use the user struct
❌ **Don't** forget to update `on_mount` hooks when migrating

✅ **Do** use Scope structs for authentication context
✅ **Do** use bracket access in templates
✅ **Do** extend scopes with roles and permissions
✅ **Do** test both authenticated and unauthenticated states

## Integration

| Skill | When to chain |
|-------|---------------|
| **phoenix-liveview-auth** | For `on_mount` patterns |
| **phoenix-authorization-patterns** | For access control |
| **testing-essentials** | For testing patterns |
