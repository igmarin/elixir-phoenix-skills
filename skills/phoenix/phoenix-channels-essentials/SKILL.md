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

1. **Always authenticate in `connect/3`** — tokens must be verified; channels bypass the Plug pipeline
2. **Authorize in `join/3`** — verify the user can access the requested topic
3. **Use `handle_in` for client-to-server, `push` for server-to-client, `broadcast` for server-to-all**
4. **Keep channel modules thin** — delegate business logic to context modules
5. **Use Presence for tracking connected users** — don't roll your own presence tracking
6. **Return `{:reply, :ok, socket}` or `{:reply, {:error, reason}, socket}` from `handle_in`** — never silently drop messages

---

## Setup Workflow

Follow these steps in order when setting up Phoenix Channels from scratch:

1. **Mount the socket in `endpoint.ex`** — verify `socket "/socket", MyAppWeb.UserSocket, ...` is present
2. **Generate a token server-side** — sign with `Phoenix.Token.sign/3` after user authentication
3. **Verify the token in `connect/3`** — reject connections with `:error` on invalid tokens. If auth fails, confirm salt matches between `sign` and `verify` and `max_age` hasn't expired; test in IEx with `Phoenix.Token.verify(endpoint, salt, token, max_age: 1_209_600)`
4. **Authorize topics in `join/3`** — check user membership/permissions before returning `{:ok, socket}`
5. **Implement `handle_in` clauses** — route client messages to context functions; broadcast or reply as needed
6. **Add Presence tracking** — call `Presence.track/3` in `handle_info(:after_join, ...)` if user lists are required
7. **Test the connection** — confirm `"Transport connected"` in the browser console, or run `wscat -c 'ws://localhost:4000/socket/websocket?token=TOKEN&vsn=2.0.0'`. If connection fails: verify socket is mounted in `endpoint.ex`, token is valid, and the client is passing the correct params key.

---

## Socket Authentication

Use token-based authentication — session-based auth is unavailable in channels.

### Step 1 — Verify socket is mounted in `endpoint.ex`

```elixir
# lib/my_app_web/endpoint.ex
socket "/socket", MyAppWeb.UserSocket,
  websocket: true,
  longpoll: false
```

### Step 2 — Generate Tokens (Server Side)

```elixir
defmodule MyAppWeb.UserAuth do
  def generate_socket_token(conn) do
    Phoenix.Token.sign(conn, "user socket", conn.assigns.current_user.id)
  end
end
```

### Step 3 — Verify Tokens in the Socket

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

### Step 4 — Connect from the Client (JavaScript)

```javascript
import { Socket } from "phoenix"

const socket = new Socket("/socket", { params: { token: window.userToken } })
socket.connect()

const channel = socket.channel("room:42", {})
channel.join()
  .receive("ok", resp => console.log("Joined successfully", resp))
  .receive("error", resp => console.error("Unable to join", resp))
```

---

## Topic Authorization, handle_in, and Presence Tracking

The following is a complete `RoomChannel` that combines authorization, message handling, and Presence tracking:

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
    user_id = socket.assigns.user_id

    if Rooms.member?(room_id, user_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second))
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
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

## Related Skills

- **phoenix-pubsub-patterns** — underlying PubSub primitives used by Channels and Presence
- **phoenix-liveview-essentials** — use instead of Channels for server-rendered real-time UI
- **testing-essentials** — patterns for testing channel joins, handle_in, and Presence
