---
name: liveview-streams
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for handling large collections in LiveView. Invoke before rendering lists with 100+ items.
  Covers Phoenix.LiveView.stream/4, stream_insert, stream_delete, DOM patching efficiency,
  and pagination with streams. Available in LiveView 0.19+.
  Trigger words: stream, LiveView stream, large list, pagination, DOM patching, stream_insert, stream_delete.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# LiveView Streams

Phoenix LiveView streams (0.19+) provide efficient rendering of large collections by patching only changed DOM elements.

## RULES — Follow these with no exceptions

1. **Use streams for collections with 100+ items** — regular assigns re-render the entire list on every change
2. **Initialize streams in `mount/3`** with `stream(socket, :name, collection)`
3. **Use `stream_insert/3` and `stream_delete/3`** for incremental updates — never replace the entire stream
4. **Use `phx-update="stream"` in templates** — required for stream DOM patching
5. **Set DOM IDs with `id` attribute** — each streamed item needs a unique DOM ID
6. **Use `stream_configure/3` for custom DOM IDs** — when default IDs don't match your needs
7. **Combine with pagination or infinite scroll** — don't stream unlimited items

---

## Basic Stream Pattern

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Initialize stream with initial data
    {:ok, stream(socket, :posts, Blog.list_posts())}
  end

  @impl true
  def handle_event("create", %{"post" => params}, socket) do
    {:ok, post} = Blog.create_post(params)

    # Insert at the beginning of the stream
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Blog.get_post!(id)
    {:ok, _} = Blog.delete_post(post)

    # Delete from stream by DOM ID
    {:noreply, stream_delete(socket, :posts, post)}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end
end
```

---

## Template with Streams

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id} class="post">
    <h3><%= post.title %></h3>
    <p><%= post.body %></p>

    <button phx-click="delete" phx-value-id={post.id}>
      Delete
    </button>
  </div>
</div>
```

**Verify after adding the template:** Open browser DevTools → Network → WS frames. Confirm incoming frames contain targeted patch operations for individual items, not full list replacements. If you see full re-renders, check:
- `phx-update="stream"` is present on the container `<div>`
- `id={dom_id}` is present on each item element

---

## Stream Configuration

```elixir
# Configure custom DOM ID generation
def mount(_params, _session, socket) do
  socket =
    socket
    |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
    |> stream(:posts, Blog.list_posts())

  {:ok, socket}
end
```

---

## Infinite Scroll with Streams

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, 1)
     |> assign(:loading, false)
     |> stream(:posts, Blog.list_posts(page: 1, per_page: @per_page))}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    page = socket.assigns.page + 1
    new_posts = Blog.list_posts(page: page, per_page: @per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> stream_insert_many(:posts, new_posts)}
  end

  defp stream_insert_many(socket, name, items) do
    Enum.reduce(items, socket, fn item, acc ->
      stream_insert(acc, name, item)
    end)
  end
end
```

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <%= post.title %>
  </div>
</div>

<div phx-hook="InfiniteScroll" data-page={@page}>
  <button phx-click="load_more" disabled={@loading}>
    Load More
  </button>
</div>
```

**Verify after implementing load_more:** Trigger the event and confirm in DevTools WS frames that only the new batch of items is appended, not the entire list. If DOM IDs collide across pages, items will overwrite each other — ensure your ID scheme is globally unique.

---

## Debugging Checklist

If stream patching is not working as expected, check for:

- Missing `phx-update="stream"` on the container `<div>`
- Missing `id={dom_id}` on each item element
- Accidentally replacing the entire stream assign instead of using `stream_insert`/`stream_delete`
- DOM ID collisions caused by non-unique item IDs
