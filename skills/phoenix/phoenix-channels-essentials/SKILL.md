---
name: phoenix-channels-essentials
type: atomic
tags: [atomic]
license: MIT
description: >-
  Handles all Phoenix Channels work. Use when building socket authentication, topic authorization,
  handle_in patterns, Presence tracking, or channel testing. Covers non-LiveView real-time features
  for mobile clients, SPAs, and external APIs. Trigger words: Channels, socket, channel, Presence,
  handle_in, topic, real-time, WebSocket.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix Channels Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

## RULES

1. **Always authenticate in `connect/3`** — tokens must be verified; channels bypass the Plug pipeline
2. **Authorize in `join/3`** — verify the user can access the requested topic
3. **Use `handle_in` for client-to-server, `push` for server-to-client, `broadcast` for server-to-all**
4. **Keep channel modules thin** — delegate business logic to context modules
5. **Use Presence for tracking connected users** — don't roll your own presence tracking
6. **Return `{:reply, :ok, socket}` or `{:reply, {:error, reason}, socket}` from `handle_in`** — never silently drop messages

---

## Setup Checklist

1. Mount the socket in `endpoint.ex` → see [Socket Authentication](#socket-authentication)
2. Generate a token server-side after user authentication → see [Step 2](#step-2--generate-tokens-server-side)
3. Verify the token in `connect/3`; if auth fails, confirm salt matches between `sign` and `verify` and `max_age` hasn't expired → see [Step 3](#step-3--verify-tokens-in-the-socket)
4. Authorize topics in `join/3` → see [Topic Authorization](#topic-authorization)
5. Implement `handle_in` clauses routing client messages to context functions → see [handle_in Patterns](#handle_in-patterns)
6. Add Presence tracking via `Presence.track/3` in `handle_info(:after_join, ...)` → see [Presence Tracking](#presence-tracking)
7. Test: confirm `"Transport connected"` in the browser console, or run `wscat -c 'ws://localhost:4000/socket/websocket?token=TOKEN&vsn=2.0.0'`. If connection fails: verify socket is mounted in `endpoint.ex`, token is valid, and the client is passing the correct params key.

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

## Topic Authorization

Authorize in `join/3` before allowing a client into a topic:

```elixir
defmodule MyAppWeb.RoomChannel do
  use MyAppWeb, :channel
  alias MyAppWeb.Presence

  @impl true
  def join("room:" <> room_id, _payload, socket) do
    user_id = socket.assigns.user_id

    # Delegate authorization to the context module — keeps the channel thin
    if Rooms.member?(room_id, user_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end
```

---

## handle_in Patterns

Route client messages to context functions and always return an explicit reply:

```elixir
@impl true
def handle_in("new_message", %{"body" => body}, socket) do
  sanitized_body = String.slice(body || "", 0, 10_000) |> String.trim()

  broadcast!(socket, "new_message", %{
    body: sanitized_body,
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
```

---

## Presence Tracking

Define a Presence module once per app, then track users in `handle_info(:after_join, ...)`:

```elixir
defmodule MyAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :my_app,
    pubsub_server: MyApp.PubSub
end
```

```elixir
# Inside RoomChannel (after join/3 sends :after_join via send/2)
@impl true
def handle_info(:after_join, socket) do
  {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
    online_at: inspect(System.system_time(:second))
  })

  push(socket, "presence_state", Presence.list(socket))
  {:noreply, socket}
end
```

---

## Channel Testing

Use `Phoenix.ChannelTest` to test socket connections, joins, and message handling:

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase

  setup do
    user_id = 1
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", user_id)

    {:ok, socket} =
      Phoenix.ChannelTest.connect(MyAppWeb.UserSocket, %{"token" => token})

    {:ok, _, socket} =
      Phoenix.ChannelTest.subscribe_and_join(socket, MyAppWeb.RoomChannel, "room:42")

    %{socket: socket, user_id: user_id}
  end

  test "new_message broadcasts to room", %{socket: socket} do
    Phoenix.ChannelTest.push(socket, "new_message", %{"body" => "hello"})
    assert_broadcast "new_message", %{body: "hello"}
    assert_reply ref, :ok
  end

  test "join is rejected when user is not a room member" do
    user_id = 99
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", user_id)
    {:ok, socket} = Phoenix.ChannelTest.connect(MyAppWeb.UserSocket, %{"token" => token})

    assert {:error, %{reason: "unauthorized"}} =
             Phoenix.ChannelTest.join(socket, MyAppWeb.RoomChannel, "room:42")
  end

  test "connect rejects missing token" do
    assert :error = Phoenix.ChannelTest.connect(MyAppWeb.UserSocket, %{})
  end
end
```
