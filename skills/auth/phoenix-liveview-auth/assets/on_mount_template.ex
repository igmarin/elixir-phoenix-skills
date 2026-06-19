# LiveView on_mount Authentication Templates

## Phoenix 1.7 (current_user)

```elixir
# lib/my_app_web/user_auth.ex
defmodule MyAppWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias MyApp.Accounts

  def on_mount(:require_authenticated_user, _params, session, socket) do
    case session["user_token"] do
      nil ->
        {:halt, redirect(socket, to: "/users/log_in")}

      user_token ->
        user = Accounts.get_user_by_session_token(user_token)

        if user do
          {:cont, assign(socket, :current_user, user)}
        else
          {:halt, redirect(socket, to: "/users/log_in")}
        end
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    user =
      case session["user_token"] do
        nil -> nil
        token -> Accounts.get_user_by_session_token(token)
      end

    {:cont, assign(socket, :current_user, user)}
  end

  # Usage in router:
  # live_session :require_authenticated_user, on_mount: [{MyAppWeb.UserAuth, :require_authenticated_user}] do
  #   live "/dashboard", DashboardLive
  # end
end
```

## Phoenix 1.8+ (Scope)

```elixir
# lib/my_app_web/user_auth.ex
defmodule MyAppWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias MyApp.Accounts
  alias MyApp.Scope

  def on_mount(:require_authenticated_user, _params, session, socket) do
    scope = get_scope_from_session(session)

    if Scope.authenticated?(scope) do
      {:cont, assign(socket, :current_scope, scope)}
    else
      {:halt, redirect(socket, to: ~p"/users/log_in")}
    end
  end

  def on_mount(:mount_current_scope, _params, session, socket) do
    scope = get_scope_from_session(session)
    {:cont, assign(socket, :current_scope, scope)}
  end

  defp get_scope_from_session(session) do
    case session["user_token"] do
      nil -> Scope.anonymous()
      token -> get_scope_from_token(token)
    end
  end

  defp get_scope_from_token(token) do
    case Accounts.get_user_by_session_token(token) do
      nil -> Scope.anonymous()
      user -> Scope.for_user(user)
    end
  end
end
```

## With Role-based Authorization

```elixir
defmodule MyAppWeb.UserAuth do
  alias MyApp.Scope

  def on_mount(:require_admin, _params, _session, socket) do
    scope = socket.assigns.current_scope

    if Scope.can?(scope, :admin) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: ~p"/")}
    end
  end

  # Usage in router with chained hooks:
  # live_session :admin,
  #   on_mount: [
  #     {MyAppWeb.UserAuth, :require_authenticated_user},
  #     {MyAppWeb.UserAuth, :require_admin}
  #   ] do
  #   live "/admin", AdminDashboardLive
  # end
end
```
