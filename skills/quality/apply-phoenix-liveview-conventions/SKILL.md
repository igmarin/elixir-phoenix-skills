---
name: apply-phoenix-liveview-conventions
type: atomic
tags: [atomic, quality]
license: MIT
description: >
  Use when writing new LiveView code in Phoenix applications. Enforces consistent patterns
  for mount/handle_event/handle_info/handle_params callbacks, HEEx component structure,
  form binding, socket assigns, and error handling. Covers the two-phase rendering lifecycle,
  connected? guards, function components, and the assign-error-to-socket pattern.
  Trigger words: phoenix conventions, liveview conventions, apply phoenix patterns,
  liveview patterns, follow phoenix best practices, heex component, liveview mount,
  handle_event convention, phoenix liveview.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Apply Phoenix LiveView Conventions

Use this skill when writing new LiveView modules or modifying existing LiveView code to ensure consistent, idiomatic Phoenix patterns.

## RULES — Follow these with no exceptions

1. **Always use `@impl true`** before every callback (mount, handle_event, handle_info, handle_params, render)
2. **Initialize all assigns in mount** — static defaults go in mount, URL-dependent assigns go in handle_params
3. **Guard side effects with `connected?(socket)`** — PubSub subscriptions, timers, and async work only run when connected
4. **Return `{:noreply, socket}` from handle_event/handle_info** — never `{:reply, ...}` unless broadcast is needed
5. **Assign errors to socket, don't raise** — use `put_flash` and changeset assigns for error states
6. **Use function components (def, not defp)** for reusable HEEx markup — export via `~H"""` sigil
7. **Use `with` for multi-step error handling** in event handlers instead of nested case
8. **Never query the database directly from a LiveView** — call context functions instead

---

## Two-Phase Rendering

LiveView renders twice per page load:

| Phase | Request | `connected?(socket)` | Side effects |
|-------|---------|---------------------|--------------|
| **Disconnected** | HTTP | `false` | No PubSub, no timers |
| **Connected** | WebSocket | `true` | PubSub, timers, async work |

**Always initialize assigns to safe defaults in Phase 1** so the static HTML never raises a `KeyError` before WebSocket connects.

```elixir
@impl true
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:user, nil)
    |> assign(:loading, false)
    |> assign(:data, [])

  {:ok, socket}
end
```

---

## Mount Callback

```elixir
@impl true
def mount(_params, _session, socket) do
  # Static defaults here
  socket = assign(socket, page_title: "LiveView")

  # Guard side effects — only run when WebSocket is connected
  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "some-topic")
  end

  {:ok, socket}
end
```

**Checkpoint:** Static HTML must render without `KeyError` before WebSocket connects.

---

## Handle Event

```elixir
@impl true
def handle_event("save", %{"post" => params}, socket) do
  case Posts.create_post(params) do
    {:ok, post} ->
      socket =
        socket
        |> put_flash(:info, "Saved!")
        |> assign(:post, post)

      {:noreply, socket}

    {:error, %Ecto.Changeset{} = changeset} ->
      socket =
        socket
        |> put_flash(:error, "Please correct the errors")
        |> assign(:changeset, changeset)

      {:noreply, socket}
  end
end
```

### With for Multi-Step Error Handling

```elixir
@impl true
def handle_event("process", %{"id" => id}, socket) do
  with {:ok, item} <- Items.get_item(id),
       {:ok, result} <- Items.process(item) do
    {:noreply, assign(socket, :result, result)}
  else
    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, "Item not found")}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Processing failed")}
  end
end
```

---

## Handle Info

```elixir
@impl true
def handle_info({:item_updated, item}, socket) do
  {:noreply, update(socket, :items, fn items -> [item | items] end)}
end

@impl true
def handle_info(%{event: "presence_diff"}, socket) do
  {:noreply, assign(socket, :online_count, Presence.count())}
end
```

---

## Handle Params

Called in **both** render phases. Place URL-dependent assigns here.

```elixir
@impl true
def handle_params(%{"id" => id}, _uri, socket) do
  post = Posts.get_post!(id)

  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "post:#{id}")
  end

  {:noreply, assign(socket, :post, post)}
end

@impl true
def handle_params(_params, _uri, socket) do
  {:noreply, socket}
end
```

---

## HEEx Component Structure

### Function Components (exported, reusable)

```elixir
defmodule MyAppWeb.Components do
  use Phoenix.Component

  def card(assigns) do
    ~H"""
    <div class="card">
      <h3><%= @title %></h3>
      <p><%= @content %></p>
    </div>
    """
  end

  def badge(assigns) do
    ~H"""
    <span class={"badge badge-#{@variant}"}><%= @label %></span>
    """
  end
end
```

**Usage in templates:**
```heex
<.card title="Hello" content="World" />
<.badge variant="success" label="Active" />
```

### Slot Patterns for Children

```elixir
def modal(assigns) do
  ~H"""
  <div class="modal">
    <header><%= @title %></header>
    <%= render_slot(@inner_block) %>
    <footer><%= render_slot(@footer) %></footer>
  </div>
  """
end
```

**Usage:**
```heex
<.modal title="Confirm">
  Are you sure?
  <:footer>
    <button phx-click="cancel">Cancel</button>
  </:footer>
</.modal>
```

---

## Form Binding

```elixir
@impl true
def mount(_params, _session, socket) do
  changeset = Post.changeset(%Post{}, %{})
  {:ok, assign(socket, form: to_form(changeset))}
end

@impl true
def handle_event("validate", %{"post" => params}, socket) do
  changeset =
    %Post{}
    |> Post.changeset(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset))}
end

@impl true
def handle_event("save", %{"post" => params}, socket) do
  case Posts.create_post(params) do
    {:ok, _post} ->
      {:noreply, put_flash(socket, :info, "Created!")}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, form: to_form(changeset))}
  end
end
```

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:title]} label="Title" />
  <.input field={@form[:body]} type="textarea" label="Body" />
  <:actions>
    <.button>Save</.button>
  </:actions>
</.simple_form>
```

---

## Socket Assigns — Best Practices

```elixir
# Single assign
socket = assign(socket, :count, 0)

# Multiple assigns
socket = assign(socket, count: 0, name: "User", active: true)

# Update existing
socket = update(socket, :count, &(&1 + 1))
```

**In render/1** — direct access is safe when initialized in mount:
```elixir
def render(assigns) do
  ~H"""<p>Count: <%= @count %></p>"""
end
```

**In helper functions** — use `Map.get` for optional assigns:
```elixir
defp format_user(socket) do
  case Map.get(socket.assigns, :current_user) do
    nil -> "Guest"
    user -> user.name
  end
end
```

---

## Error Handling Patterns

### Assign Errors to Socket (never raise)

```elixir
def handle_event("submit", %{"data" => data}, socket) do
  case process_data(data) do
    {:ok, result} ->
      {:noreply, assign(socket, :result, result)}

    {:error, :invalid} ->
      {:noreply, put_flash(socket, :error, "Invalid data")}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
  end
end
```

### Flash Messages

```elixir
put_flash(socket, :info, "Success message")
put_flash(socket, :error, "Error message")
put_flash(socket, :warning, "Warning message")
```

---

## Common Mistakes

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `def handle_event(...)` without `@impl true` | `@impl true` before every callback |
| Side effects (PubSub, DB calls) outside `connected?` guard | Always guard with `if connected?(socket)` |
| `raise` in handle_event for expected errors | Assign errors to socket with `put_flash` |
| Nested `case` for multi-step error handling | Use `with` for 2+ fallible operations |
| Querying `Repo` directly in LiveView | Call context functions (`Posts.get_post!`) |
| `defp` for component used in template | Use `def` (exported function component) |
| Mutating socket.assigns directly | Use `assign`/`update` returning new socket |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | apply-phoenix-liveview-conventions | code-quality |
| phoenix-liveview-essentials | apply-phoenix-liveview-conventions | testing-essentials |

**Companion skills:**
- `phoenix-liveview-essentials` — deep LiveView callback lifecycle reference
- `liveview-streams` — large collection rendering (100+ items)
- `phoenix-pubsub-patterns` — PubSub subscription management
- `phoenix-liveview-auth` — authentication in LiveViews