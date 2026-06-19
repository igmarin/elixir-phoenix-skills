---
name: phoenix-pubsub-patterns
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL PubSub and real-time broadcast work. Invoke before writing PubSub.subscribe,
  broadcast, or handle_info for real-time updates. Covers subscription patterns, broadcasting from
  contexts, topic naming, scoped broadcasting, immutable assign updates, and testing.
  Trigger words: PubSub, subscribe, broadcast, handle_info, real-time, topic, presence.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix PubSub Patterns

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY PubSub or real-time broadcast code.

## Implementation Workflow

1. **Subscribe in `mount`** — guard with `if connected?(socket)` to prevent duplicate subscriptions
2. **Broadcast from context** — add a private `broadcast/2` helper that fires only on `{:ok, result}`
3. **Handle in `handle_info/2`** — update assigns immutably with `update/3`
4. **Verify with a test** — call the context function and assert the LiveView reflects the change

---

## Key Constraints

- Guard subscriptions with `if connected?(socket)` — prevents duplicates on static render
- Broadcast from contexts, not LiveViews — keeps real-time logic in the business layer
- Use consistent topic naming: `"resource:id"` for specific resources, `"resource:action"` for collection-wide events
- Handle PubSub messages in `handle_info/2`, never in `handle_event/3`
- Update assigns immutably with `update/3` — never replace the full list
- Test the full cycle by calling context functions and asserting LiveView updates

---

## Subscription Pattern

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "posts")
    end

    {:ok, assign(socket, :posts, list_posts())}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply,
     update(socket, :posts, fn posts ->
       Enum.map(posts, fn
         p when p.id == post.id -> post
         p -> p
       end)
     end)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply,
     update(socket, :posts, fn posts ->
       Enum.reject(posts, &(&1.id == post.id))
     end)}
  end
end
```

---

## Broadcasting from Contexts

Topic naming conventions:
- `"posts"` — collection-wide; events: `{:post_created, post}`, `{:post_updated, post}`, `{:post_deleted, post}`
- `"posts:#{post.id}"` — specific resource; events: `{:post_updated, post}`, `{:comment_added, comment}`
- `"users:#{user.id}"` — user-scoped; events: `{:notification, notification}`, `{:message_received, message}`

```elixir
defmodule MyApp.Blog do
  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:post_created)
  end

  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
    |> broadcast(:post_updated)
  end

  def delete_post(%Post{} = post) do
    post
    |> Repo.delete()
    |> broadcast(:post_deleted)
  end

  # Only broadcast on success
  defp broadcast({:ok, post}, event) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "posts", {event, post})
    {:ok, post}
  end

  defp broadcast({:error, changeset}, _event) do
    {:error, changeset}
  end
end
```

---

## Testing the Full PubSub Cycle

Test by calling context functions and asserting the LiveView reflects the update — do not test `PubSub.broadcast` in isolation.

```elixir
defmodule MyAppWeb.PostLive.IndexTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "creates a post and LiveView updates in real time", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts")

    # Call the context function — it broadcasts internally
    {:ok, post} = MyApp.Blog.create_post(%{title: "Hello", body: "World"})

    # Assert the LiveView received and rendered the broadcast
    assert render(view) =~ post.title
  end

  test "deletes a post and LiveView removes it", %{conn: conn} do
    post = insert(:post)
    {:ok, view, _html} = live(conn, ~p"/posts")

    {:ok, _} = MyApp.Blog.delete_post(post)

    refute render(view) =~ post.title
  end
end
```

---

## Troubleshooting / Validation Checkpoints

- **Subscription not firing?** Verify the LiveView is fully connected: subscriptions inside `if connected?(socket)` only run after WebSocket upgrade, not on the initial static render.
- **Broadcast sent but LiveView not updating?** Confirm the topic string in `subscribe` and `broadcast` match exactly (case-sensitive). Add a temporary `IO.inspect` in `handle_info/2` to confirm the message is arriving.
- **Duplicate messages?** You subscribed outside the `if connected?(socket)` guard — the static render and the live render both subscribed.
- **`handle_info` clause missing?** An unhandled PubSub message will crash the LiveView process. Add a catch-all `def handle_info(_, socket), do: {:noreply, socket}` if other processes may send unexpected messages.
