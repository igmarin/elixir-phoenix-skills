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

Phoenix LiveView streams (0.19+) provide efficient rendering of large collections by patching only changed DOM elements.

## RULES — Follow these with no exceptions

1. **Use streams for collections with 100+ items** — regular assigns re-render the entire list on every change
2. **Initialize streams in `mount/3`** with `stream(socket, :name, collection)`
3. **Use `stream_insert/3` and `stream_delete/3`** for incremental updates — never replace the entire stream
4. **Use `phx-update="stream"` in templates** — required for stream DOM patching
5. **Set DOM IDs with `id` attribute** — each streamed item needs a unique DOM ID
6. **Use `stream_configure/3` for custom DOM IDs** — when default IDs don't match your needs
7. **Combine with pagination or infinite scroll** — don't stream unlimited items
8. **Always use `Repo.preload` before streaming** — preloading ensures data is loaded
9. **Use `at:` option for ordered insertion** — control where new items appear in the stream

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

## PubSub Integration with Streams

Broadcast stream updates from background processes:

```elixir
# In your context/module
def create_post(attrs) do
  {:ok, post} = Repo.insert(Post.changeset(%Post{}, attrs))

  # Broadcast to all connected clients
  Phoenix.PubSub.broadcast(MyApp.PubSub, "posts", {:post_created, post})

  {:ok, post}
end

# In the LiveView
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

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
    # Insert at beginning when broadcast received
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end
end
```

---

## Resetting and Replacing Streams

When you need to reset a stream entirely (e.g., after filtering):

```elixir
def handle_event("filter", %{"status" => status}, socket) do
  filtered_posts = Blog.list_posts_by_status(status)

  {:noreply,
   socket
   |> stream(:posts, filtered_posts, reset: true)}
  # The reset: true option clears existing items before inserting new ones
end
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

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | liveview-streams | testing-essentials |

---

## Search and Filtering with Streams

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:query, "")
     |> assign(:filter, "all")
     |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
     |> stream(:posts, Blog.list_posts())}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    filtered_posts =
      socket.assigns.filter
      |> Blog.list_posts_filtered()
      |> Enum.filter(fn post ->
        String.contains?(String.downcase(post.title), String.downcase(query))
      end)

    {:noreply,
     socket
     |> assign(:query, query)
     |> stream(:posts, filtered_posts, reset: true)}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filtered_posts = Blog.list_posts_filtered(filter)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> stream(:posts, filtered_posts, reset: true)}
  end
end
```

---

## Edit-in-Place with Streams

```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
     |> stream(:posts, Blog.list_posts())
     |> assign(:editing_id, nil)}
  end

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_id, id)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_id, nil)}
  end

  @impl true
  def handle_event("save_edit", %{"id" => id, "post" => post_params}, socket) do
    post = Blog.get_post!(id)
    {:ok, updated_post} = Blog.update_post(post, post_params)

    {:noreply,
     socket
     |> assign(:editing_id, nil)
     |> stream_insert(:posts, updated_post)}
  end
end
```

```heex
<div id="posts" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <%= if @editing_id == post.id do %>
      <!-- Edit mode -->
      <.form phx-submit="save_edit" phx-click="cancel_edit">
        <input name="post[title]" value={post.title} />
        <button type="submit">Save</button>
        <button type="button" phx-click="cancel_edit">Cancel</button>
      </.form>
    <% else %>
      <!-- Display mode -->
      <h3><%= post.title %></h3>
      <button phx-click="start_edit" phx-value-id={post.id}>Edit</button>
    <% end %>
  </div>
</div>
```

---

## Sorting with Streams

```elixir
def handle_event("sort", %{"column" => column}, socket) do
  current_direction = socket.assigns.sort_direction || :asc
  new_direction = if current_direction == :asc, do: :desc, else: :asc

  sorted_posts =
    socket.assigns.posts
    |> Enum.sort_by(&Map.get(&1, String.to_existing_atom(column)), new_direction)

  {:noreply,
   socket
   |> assign(:sort_column, column)
   |> assign(:sort_direction, new_direction)
   |> stream(:posts, sorted_posts, reset: true)}
end
```

---

## Performance Considerations

1. **Batch DOM operations** — When inserting multiple items, use `stream_insert_many` to batch the renders
2. **Lazy loading** — Consider using `paginate: true` option for very large datasets
3. **Debounce search** — Add `phx-debounce="blur"` to search inputs to avoid excessive re-renders
4. **Virtual scrolling** — For very large lists (10000+), consider combining streams with virtual scrolling

---

## Real-World Example: Activity Feed

```elixir
defmodule MyAppWeb.ActivityLive do
  use MyAppWeb, :live_view

  @per_page 50

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "activity")
    end

    {:ok,
     socket
     |> assign(:page, 1)
     |> assign(:loading, false)
     |> stream_configure(:activities, dom_id: &"activity-#{&1.id}")
     |> stream(:activities, Activity.list_activities(page: 1, per_page: @per_page))}
  end

  @impl true
  def handle_info({:new_activity, activity}, socket) do
    {:noreply, stream_insert(socket, :activities, activity, at: 0)}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    if socket.assigns.loading do
      {:noreply, socket}
    else
      next_page = socket.assigns.page + 1
      new_activities = Activity.list_activities(page: next_page, per_page: @per_page)

      {:noreply,
       socket
       |> assign(:page, next_page)
       |> assign(:loading, false)
       |> stream_insert_many(:activities, new_activities)}
    end
  end
end
```
