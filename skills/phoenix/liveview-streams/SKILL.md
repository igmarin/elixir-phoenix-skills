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

# LiveView Streams

## RULES — Non-Obvious Constraints

1. **Use streams for collections with 100+ items; combine with pagination or infinite scroll** — smaller lists use regular assigns; never stream unlimited items
2. **Use `stream_insert/3` and `stream_delete/3` for incremental updates** — never replace the entire stream assign
3. **Use `phx-update="stream"` in templates** — required for stream DOM patching; missing this causes full re-renders
4. **Use `reset: true` for filtering and sorting** — clears existing items before inserting the new result set

---

## End-to-End Workflow

Follow this sequence when implementing LiveView streams:

1. **Identify collection size** — see Rule 1 above for the threshold
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

# Sorting — re-fetch from the database because streams do not store items in assigns
def handle_event("sort", %{"column" => col, "direction" => dir}, socket) do
  direction = String.to_existing_atom(dir)
  sorted = Blog.list_posts(order_by: [{direction, String.to_existing_atom(col)}])

  {:noreply,
   socket
   |> assign(:sort_direction, direction)
   |> stream(:posts, sorted, reset: true)}
end
```

---

## Edit-in-Place Pattern

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
- DOM ID collisions caused by non-unique item IDs (especially across pages in infinite scroll)
- Using `stream_insert` without proper `dom_id` configuration
- Forgetting to call `stream_configure` before `stream` when using custom IDs

**Verify with DevTools:** Open browser DevTools → Network → WS frames. Confirm incoming frames contain targeted patch operations for individual items, not full list replacements. If you see full re-renders, the first two checklist items above are the most common cause.
