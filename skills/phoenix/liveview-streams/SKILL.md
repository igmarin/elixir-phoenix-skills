---
name: liveview-streams
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for handling large collections in LiveView. Invoke before rendering lists with 100+ items.
  Covers Phoenix.LiveView.stream/4, stream_insert, stream_delete, DOM patching efficiency,
  and pagination with streams. Available in LiveView 0.19+.
  Trigger words: stream, LiveView stream, large list, pagination, DOM patching, stream_insert,
  stream_delete, phx-update="stream", stream_configure, stream_many, infinite scroll,
  virtualized list, DOM ID, dom_id.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# LiveView Streams

## RULES — Follow these with no exceptions

1. **Use streams for collections with 100+ items** — smaller lists use regular assigns
2. **Use `stream_insert/3` and `stream_delete/3` for incremental updates** — never replace the entire stream assign
3. **Use `phx-update="stream"` in templates** — required for stream DOM patching; missing this causes full re-renders
4. **Combine with pagination or infinite scroll** — do not stream unlimited items
5. **Use `reset: true` for filtering and sorting** — clears existing items before inserting the new result set

---

## End-to-End Workflow

Follow this sequence when implementing LiveView streams:

1. **Identify collection size** — use streams only for 100+ items; smaller lists use regular assigns
2. **Define DOM ID strategy** — decide on `id` attribute format (e.g., `post-#{post.id}`)
3. **Add `stream_configure/3`** in `mount/3` to set custom DOM ID generator
4. **Initialize stream** — call `stream(socket, :name, collection)` in `mount/3`
5. **Update template** — add `phx-update="stream"` container and `id={dom_id}` on items
6. **Handle events** — use `stream_insert`/`stream_delete` for all mutations
7. **Add handle_info** — handle Phoenix.PubSub broadcasts with stream updates
8. **Verify WS frames** — confirm targeted DOM patches in browser DevTools

---

## Basic Stream Pattern

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
     |> stream(:posts, Blog.list_posts())}
  end

  @impl true
  def handle_event("create", %{"post" => params}, socket) do
    {:ok, post} = Blog.create_post(params)
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Blog.get_post!(id)
    {:ok, _} = Blog.delete_post(post)
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

> If items re-render fully instead of patching, see the **Debugging Checklist** below.

---

## Infinite Scroll with Streams

```elixir
@per_page 20

@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page, 1)
   |> assign(:loading, false)
   |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
   |> stream(:posts, Blog.list_posts(page: 1, per_page: @per_page))}
end

@impl true
def handle_event("load_more", _params, socket) do
  page = socket.assigns.page + 1
  new_posts = Blog.list_posts(page: page, per_page: @per_page)

  {:noreply,
   socket
   |> assign(:page, page)
   |> then(fn s -> Enum.reduce(new_posts, s, &stream_insert(&2, :posts, &1)) end)}
end
```

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <%= post.title %>
  </div>
</div>

<div phx-hook="InfiniteScroll" data-page={@page}>
  <button phx-click="load_more" disabled={@loading}>Load More</button>
</div>
```

> Ensure DOM IDs are globally unique across pages — collisions cause items to overwrite each other. See the **Debugging Checklist** below if patches are not targeted.

---

## PubSub Integration with Streams

```elixir
@impl true
def mount(_params, _session, socket) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "posts")
  end

  {:ok,
   socket
   |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
   |> stream(:posts, Blog.list_posts())}
end

@impl true
def handle_info({:post_created, post}, socket) do
  {:noreply, stream_insert(socket, :posts, post, at: 0)}
end
```

Broadcast from your context:

```elixir
def create_post(attrs) do
  {:ok, post} = Repo.insert(Post.changeset(%Post{}, attrs))
  Phoenix.PubSub.broadcast(MyApp.PubSub, "posts", {:post_created, post})
  {:ok, post}
end
```

---

## Resetting and Replacing Streams

Use `reset: true` to clear existing items before inserting new ones — required for filtering and sorting:

```elixir
# Filtering
def handle_event("filter", %{"status" => status}, socket) do
  {:noreply, stream(socket, :posts, Blog.list_posts_by_status(status), reset: true)}
end

# Sorting — always re-query from the data source
def handle_event("sort", %{"column" => col}, socket) do
  direction = if socket.assigns.sort_direction == :asc, do: :desc, else: :asc
  sorted = Blog.list_posts(sort_by: String.to_existing_atom(col), direction: direction)

  {:noreply,
   socket
   |> assign(:sort_direction, direction)
   |> stream(:posts, sorted, reset: true)}
end
```

---

## Edit-in-Place Pattern

Track editing state with a regular assign; use `stream_insert` to push the updated item back into the stream:

```elixir
def handle_event("save_edit", %{"id" => id, "post" => params}, socket) do
  post = Blog.get_post!(id)
  {:ok, updated_post} = Blog.update_post(post, params)

  {:noreply,
   socket
   |> assign(:editing_id, nil)
   |> stream_insert(:posts, updated_post)}
end
```

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <%= if @editing_id == post.id do %>
      <.form phx-submit="save_edit">
        <input name="post[title]" value={post.title} />
        <button type="submit">Save</button>
        <button type="button" phx-click="cancel_edit">Cancel</button>
      </.form>
    <% else %>
      <h3><%= post.title %></h3>
      <button phx-click="start_edit" phx-value-id={post.id}>Edit</button>
    <% end %>
  </div>
</div>
```

---

## Debugging Checklist

If stream patching is not working as expected, check for:

- Missing `phx-update="stream"` on the container `<div>`
- Missing `id={dom_id}` on each item element
- Accidentally replacing the entire stream assign instead of using `stream_insert`/`stream_delete`
- DOM ID collisions caused by non-unique item IDs
- Using `stream_insert` without proper `dom_id` configuration
- Forgetting to call `stream_configure` before `stream` when using custom IDs

**To verify:** Open browser DevTools → Network → WS frames. Confirm incoming frames contain targeted patch operations for individual items, not full list replacements.

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Assign a large list with `assign(:posts, ...)` | Use `stream(socket, :posts, ...)` for 100+ items |
| Replace the whole stream to add/remove one item | Use `stream_insert/3` and `stream_delete/3` |
| Omit `phx-update="stream"` on the container | Add `phx-update="stream"` — required for DOM patching |
| Leave off `id={dom_id}` on stream items | Set `id={dom_id}` on every item element |
| Reuse non-unique DOM IDs across pages | Generate globally-unique IDs via `stream_configure/3` |
| Filter/sort by re-inserting into the existing stream | Re-query and `stream(..., reset: true)` |
| Stream an unbounded collection | Combine with pagination or infinite scroll |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | liveview-streams | phoenix-pubsub-patterns |
| apply-phoenix-liveview-conventions | liveview-streams | testing-essentials |

**Companion skills:**
- `phoenix-liveview-essentials` — LiveView callback lifecycle and assigns
- `phoenix-pubsub-patterns` — stream updates driven by real-time broadcasts
- `testing-essentials` — assert stream contents with `Phoenix.LiveViewTest`
