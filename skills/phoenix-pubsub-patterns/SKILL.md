---
name: phoenix-pubsub-patterns
type: atomic
license: MIT
description: >
  MANDATORY for ALL PubSub and real-time broadcast work. Invoke before writing PubSub.subscribe,
  broadcast, or handle_info for real-time updates. Covers subscription patterns, broadcasting from
  contexts, topic naming, scoped broadcasting, immutable assign updates, and testing.
  Trigger words: PubSub, subscribe, broadcast, handle_info, real-time, topic, presence.
metadata:
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix PubSub Patterns

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY PubSub or real-time broadcast code.

## RULES — Follow these with no exceptions

1. **Always guard subscriptions with `if connected?(socket)`** — prevents duplicate subscriptions on static render
2. **Broadcast from contexts, not LiveViews** — keeps real-time logic in the business layer
3. **Use consistent topic naming** — `"resource:id"` for specific resources, `"resource:action"` for collection-wide events
4. **Handle PubSub messages in `handle_info/2`** — never in `handle_event/3`; PubSub messages are process messages
5. **Update assigns immutably with `update/3`** — never replace the full list
6. **Test PubSub by calling context functions and asserting LiveView updates** — test the full cycle

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

## Topic Naming Conventions

```elixir
# Collection-wide — all posts
topic = "posts"
# Events: {:post_created, post}, {:post_updated, post}, {:post_deleted, post}

# Specific resource — one post
topic = "posts:#{post.id}"
# Events: {:post_updated, post}, {:comment_added, comment}

# User-scoped — all activity for a user
topic = "users:#{user.id}"
# Events: {:notification, notification}, {:message_received, message}
```

---

## Immutable Assign Updates

✅ **Good — uses update/3 for immutable prepend:**
```elixir
def handle_info({:post_created, post}, socket) do
  {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
end
```

✅ **Good — update a specific item:**
```elixir
def handle_info({:post_updated, updated_post}, socket) do
  {:noreply,
   update(socket, :posts, fn posts ->
     Enum.map(posts, fn
       post when post.id == updated_post.id -> updated_post
       post -> post
     end)
   end)}
end
```

---

## Common Pitfalls

❌ **Don't** subscribe without checking `connected?(socket)`
❌ **Don't** broadcast from LiveViews — broadcast from contexts
❌ **Don't** handle PubSub messages in `handle_event/3`
❌ **Don't** replace the full list — use `update/3`
❌ **Don't** test `PubSub.broadcast` in isolation — test the full cycle

✅ **Do** guard subscriptions with `connected?(socket)`
✅ **Do** broadcast from context modules
✅ **Do** use consistent topic naming
✅ **Do** handle messages in `handle_info/2`
✅ **Do** use `update/3` for immutable updates

## Integration

| Skill | When to chain |
|-------|---------------|
| **phoenix-liveview-essentials** | For LiveView lifecycle patterns |
| **testing-essentials** | For testing patterns |
| **phoenix-channels-essentials** | For non-LiveView real-time features |
| **liveview-streams** | For efficient rendering of large collections |
