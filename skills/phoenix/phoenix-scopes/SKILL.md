---
name: phoenix-scopes
type: atomic
tags: [atomic]
license: MIT
description: >
  Covers Phoenix 1.8+ Scope-based authentication replacing current_user, including Scope struct
  definition with roles and permissions, scope creation and usage in LiveViews and controllers,
  safe template access patterns, and step-by-step migration from current_user to scopes.
  Use when working with Phoenix 1.8+ authentication, authorization, Scope structs, current_scope,
  or migrating from current_user to the new scope-based model.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Phoenix Scopes

Phoenix 1.8 introduced `Scope` as the new authentication primitive, replacing direct `current_user` access.

## RULES — Follow these with no exceptions

1. **Use Scope structs instead of raw `current_user`** — scopes wrap the user and carry additional context such as roles, permissions, and tenant info
2. **Use bracket access in templates** — `assigns[:current_scope]` prevents crashes when unauthenticated
3. **Test both authenticated and unauthenticated states** — scope-based auth has two distinct code paths

---

## Scope Struct Definition

Define one Scope struct wrapping the user. Add roles, permissions, and tenant fields as your project requires:

```elixir
defmodule MyApp.Scope do
  defstruct [:user, :role, :permissions, :tenant]

  @type t :: %__MODULE__{
    user: MyApp.Accounts.User.t() | nil,
    role: atom() | nil,
    permissions: [atom()] | nil,
    tenant: String.t() | nil
  }

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

  # Permissions are project-specific; define per role as needed.
  defp permissions_for(:admin), do: [:read, :write, :delete, :manage_users]
  defp permissions_for(:editor), do: [:read, :write]
  defp permissions_for(:viewer), do: [:read]
  defp permissions_for(_), do: []
end
```

---

## Using Scopes in LiveViews

Access `current_scope` from `socket.assigns` and check authentication or permissions before proceeding:

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

## Migration from current_user

### Step-by-Step Migration Workflow

1. **Update the Scope struct** — define `MyApp.Scope` with `for_user/1` and `authenticated?/1` as shown above.
2. **Update `on_mount` hooks** — replace user assignment with scope assignment (see before/after below). After this step, run `mix test test/my_app_web/live/ --trace` and verify all `on_mount` tests pass before proceeding.
3. **Search and replace `@current_user`** — update all template references to `@current_scope.user`; use `assigns[:current_scope]` for optional access. After this step, run `mix test` and fix any `KeyError` or `FunctionClauseError` failures before continuing.
4. **Update context functions** — pass `scope` instead of `user` to context functions that need auth context. Re-run `mix test` to confirm no regressions.
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
