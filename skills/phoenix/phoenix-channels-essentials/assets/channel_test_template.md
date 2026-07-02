# Phoenix Channel Test Template

Copy-paste starting point for `Phoenix.ChannelTest`. Covers the three core moves:
`subscribe_and_join` in `setup`, `push` + `assert_reply`, and `assert_broadcast`.
Use `MyAppWeb.ChannelCase` so the endpoint, PubSub, and assertion macros are imported.

## Full channel test module

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase, async: true

  setup do
    user_id = 1
    token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", user_id)

    {:ok, socket} = connect(MyAppWeb.UserSocket, %{"token" => token})

    # subscribe_and_join returns {:ok, join_reply, socket} and subscribes the
    # test process to the topic so assert_broadcast/assert_push can fire.
    {:ok, _join_reply, socket} =
      subscribe_and_join(socket, MyAppWeb.RoomChannel, "room:42")

    %{socket: socket, user_id: user_id}
  end

  describe "handle_in/3" do
    test "new_message replies :ok and broadcasts to the topic", %{socket: socket} do
      ref = push(socket, "new_message", %{"body" => "hello"})

      # assert_reply matches the reply to the exact push ref
      assert_reply ref, :ok

      # assert_broadcast matches a message sent to every subscriber of the topic
      assert_broadcast "new_message", %{body: "hello"}
    end

    test "typing broadcasts the sender's id", %{socket: socket, user_id: user_id} do
      push(socket, "typing", %{})
      assert_broadcast "user_typing", %{user_id: ^user_id}
    end
  end

  describe "after join" do
    test "pushes presence_state to the joining client", %{socket: _socket} do
      # send/2 from join/3 schedules :after_join, which pushes to this client
      assert_push "presence_state", %{}
    end
  end

  describe "authorization" do
    test "join is rejected for a non-member" do
      user_id = 99
      token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user socket", user_id)
      {:ok, socket} = connect(MyAppWeb.UserSocket, %{"token" => token})

      assert {:error, %{reason: "unauthorized"}} =
               join(socket, MyAppWeb.RoomChannel, "room:42")
    end

    test "connect rejects a missing token" do
      assert :error = connect(MyAppWeb.UserSocket, %{})
    end
  end
end
```

## Assertion cheat sheet

| Macro | Asserts |
|-------|---------|
| `assert_reply ref, :ok` | The `handle_in` for `ref` replied `{:reply, :ok, socket}` |
| `assert_reply ref, :error, %{reason: r}` | The reply was `{:reply, {:error, payload}, socket}` |
| `assert_broadcast "event", payload` | The channel broadcast `event` to the topic |
| `assert_push "event", payload` | The channel pushed `event` to this client only |
| `refute_broadcast "event", _` | No such broadcast was sent |

> Pin variables with `^` (e.g. `%{user_id: ^user_id}`) to assert exact payload values.
