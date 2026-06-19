---
name: phoenix-channels-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL Phoenix Channels work. Invoke before writing socket, channel, or Presence modules.
  Covers socket authentication, topic authorization, handle_in patterns, Presence tracking,
  and testing. For non-LiveView real-time features: mobile clients, SPAs, external APIs.
  Trigger words: Channels, socket, channel, Presence, handle_in, topic, real-time, WebSocket.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix Channels Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY Phoenix Channels code. For non-LiveView real-time features.

## RULES — Follow these with no exceptions

1. **Always authenticate in `connect/3`** — channels bypass the Plug pipeline; tokens must be verified
2. **Authorize in `join/3`** — verify the user can access the requested topic
3. **Use `handle_in` for client-to-server, `push` for server-to-client, `broadcast` for server-to-all**
4. **Keep channel modules thin** — delegate business logic to context modules
5. **Use Presence for tracking connected users** — don't roll your own presence tracking
6. **Return `{:reply, :ok, socket}` or `{:reply, {:error, reason}, socket}` from `handle_in`**

---

## Socket Authentication

Channels bypass the Plug pipeline, so session-based auth doesn't work. Use token-based authentication.

### Generating Tokens (Server Side)

```elixir
defmodule MyAppWeb.UserAuth do
  def generate_socket_token(conn) do
    Phoenix.Token.sign(conn, "user socket", conn.assigns.current_user.id)
  end
end
```

### Verifying Tokens (Socket)

```elixir
defmodule MyAppWeb.UserSocket do
  use Phoenix.Socket

  channel "room:*", MyAppWeb.RoomChannel
  channel "notifications:*", MyAppWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end
```

---

## Topic Authorization

```elixir
defmodule MyAppWeb.RoomChannel do
  use MyAppWeb, :channel

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    user_id = socket.assigns.user_id

    if Rooms.member?(room_id, user_id) do
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_message", %{"body" => body}, socket) do
    broadcast!(socket, "new_message", %{
      body: body,
      user_id: socket.assigns.user_id,
      timestamp: DateTime.utc_now()
    })

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("typing", _payload, socket) do
    broadcast!(socket, "user_typing", %{user_id: socket.assigns.user_id})
    {:reply, :ok, socket}
  end
end
```

---

## Presence Tracking

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end

defmodule MyAppWeb.RoomChannel do
  use MyAppWeb, :channel
  alias MyAppWeb.Presence

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :room_id, room_id)}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second))
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
```

---

## Common Pitfalls

❌ **Don't** skip authentication in `connect/3`
❌ **Don't** skip authorization in `join/3`
❌ **Don't** put business logic in channel modules
❌ **Don't** roll your own presence tracking — use Presence
❌ **Don't** silently drop messages — always reply

✅ **Do** authenticate in `connect/3`
✅ **Do** authorize in `join/3`
✅ **Do** keep channels thin — delegate to contexts
✅ **Do** use Presence for tracking users
✅ **Do** reply to all `handle_in` messages

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-pubsub-patterns** | For LiveView real-time patterns |
| **phoenix-liveview-essentials** | For LiveView lifecycle patterns |
| **testing-essentials** | For testing patterns |
