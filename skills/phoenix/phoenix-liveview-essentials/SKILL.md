---
name: phoenix-liveview-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL LiveView work. Invoke before writing LiveView modules or .heex templates.
  Covers the two-phase rendering lifecycle, mount/handle_event/handle_info/handle_params callbacks,
  socket assigns, streams, components, form binding, error handling, and PubSub integration.
  Trigger words: LiveView, live_view, mount, handle_event, handle_info, render, HEEx, socket, assign.

---

# Phoenix LiveView Essentials

Use this skill before writing ANY LiveView module or `.heex` template.

## RULES — Follow these with no exceptions

1. **Always add `@impl true`** before every callback (mount, handle_event, handle_info, render)
2. **Initialize assigns before they're accessed in render/1** — use mount/3 for static defaults, handle_params/3 for URL-dependent assigns
3. **Check `connected?(socket)`** before PubSub subscriptions, timers, or side effects
4. **Use `Map.get(assigns, :key, default)`** for optional assigns in helper functions
5. **Return proper tuples** — `{:ok, socket}` from mount, `{:noreply, socket}` from handle_event
6. **Use `with` for error handling** in event handlers — assign errors to socket, don't crash
7. **Never use `auto_upload: true` with form submission** — manual uploads are required to control when files are consumed relative to form data
8. **Check `core_components.ex` for existing components** before creating custom ones
9. **Never query the database directly from LiveViews** — call context functions instead
10. **Use streams for large collections** — see `liveview-streams` skill for details


## Recommended Build Order

1. **Define `mount/3`** — initialize all assigns with static defaults
2. **Add `handle_params/3`** — set URL-dependent assigns, subscribe to PubSub
3. **Write `render/1`** — reference only assigns initialized in steps 1–2
4. **Add `handle_event/3`** — implement user interactions with proper error handling
5. **Verify static render** — confirm no `KeyError` before WebSocket connects


## Critical Concept: Two-Phase Rendering

Both phases run `mount` → `handle_params` → render. Initialize all assigns to safe defaults in Phase 1 (`connected?(socket)` is `false`) so the static HTML never raises a `KeyError`. Side effects, PubSub, and timers only work in Phase 2 (`connected?(socket)` is `true`).


## Mount Callback

```elixir
@impl true
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:user, nil)
    |> assign(:loading, false)
    |> assign(:data, [])

  if connected?(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
  end

  {:ok, socket}
end
```

**Defer expensive operations to the connected phase:**

```elixir
@impl true
def mount(_params, _session, socket) do
  socket =
    if connected?(socket) do
      assign(socket, :data, run_expensive_query())
    else
      assign(socket, :data, [])
    end

  {:ok, socket}
end
```

**✅ Validation checkpoint:** Verify all assigns used in render/1 are initialized — the static render must display without a `KeyError`.


## Handle Event

```elixir
@impl true
def handle_event("delete", %{"id" => id}, socket) do
  case Posts.delete_post(id) do
    {:ok, _post} ->
      {:noreply, assign(socket, :posts, Posts.list_posts())}

    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, "Could not delete post")}
  end
end
```

For create/update events, use the Error Handling pattern below — assign changeset errors to the socket rather than raising.

**✅ Validation checkpoint:** Each handler must return `{:noreply, socket}`; error paths assign errors to the socket rather than raising.


## Handle Info

Match on the message shape and update assigns accordingly:

```elixir
@impl true
def handle_info({:post_updated, post}, socket) do
  {:noreply, assign(socket, :post, post)}
end
```


## Handle Params

Called in BOTH render phases on URL changes. Place URL-dependent assigns here so they are available in both static and connected renders.

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


## Socket Assigns

Assigns drive rendering. Use `assign/3` for direct values and `update/3` when the new value depends on the current one. In `render/1`, direct `@key` access is safe when the assign is initialized in `mount`; in helper functions, guard optional assigns with `Map.get/3` to avoid `KeyError`.

**Single assign:**
```elixir
socket = assign(socket, :count, 0)
```

**Multiple assigns at once:**
```elixir
socket =
  socket
  |> assign(:user, user)
  |> assign(:loading, false)
  |> assign(:posts, [])
```

**Incremental change — depend on the current value:**

❌ **Bad — reads the assign manually, then re-assigns:**
```elixir
count = socket.assigns.count
assign(socket, :count, count + 1)
```

✅ **Good — `update/3` transforms the current value:**
```elixir
update(socket, :count, fn count -> count + 1 end)
```

**Safe helper access:**

❌ **Bad — a maybe-missing `@current_user` raises `KeyError`:**
```elixir
defp format_user(socket) do
  socket.assigns.current_user.name
end
```

✅ **Good — guard optional assigns with `Map.get/3`:**
```elixir
defp format_user(socket) do
  case Map.get(socket.assigns, :current_user, nil) do
    nil -> "Guest"
    user -> user.name
  end
end
```


## Live Navigation

```elixir
# Full page reload (new LiveView)
{:noreply, push_navigate(socket, to: ~p"/users")}

# Patch (same LiveView, different params)
{:noreply, push_patch(socket, to: ~p"/posts/#{post}")}
```


## Form Binding

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:title]} label="Title" />
  <.input field={@form[:body]} type="textarea" label="Body" />
  <:actions>
    <.button>Save</.button>
  </:actions>
</.simple_form>
```

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
```


## Error Handling

```elixir
@impl true
def handle_event("save", %{"post" => post_params}, socket) do
  case Posts.create_post(post_params) do
    {:ok, post} ->
      socket =
        socket
        |> put_flash(:info, "Created!")
        |> assign(:post, post)

      {:noreply, socket}

    {:error, %Ecto.Changeset{} = changeset} ->
      socket =
        socket
        |> put_flash(:error, "Please correct the errors")
        |> assign(:changeset, changeset)

      {:noreply, socket}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "An error occurred: #{reason}")}
  end
end
```


Related skills: `liveview-streams`, `phoenix-pubsub-patterns`, `phoenix-liveview-auth`, `phoenix-scopes`, `testing-essentials`.


## When Not to Use

- **Static pages or controller/view patterns** — no LiveView module or `.heex` template involved
- **Large collection rendering (100+ items)** — use `liveview-streams` instead for DOM efficiency
- **Authentication flows** — use `phoenix-liveview-auth` and `phoenix-scopes` instead


## Testing LiveViews

Drive the full lifecycle with `Phoenix.LiveViewTest` — mount, render, events, and navigation. See [`assets/liveview_test_template.md`](assets/liveview_test_template.md) for a LiveView test template and [`assets/component_test_template.md`](assets/component_test_template.md) for a function-component test template.


## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Access an assign in `render/1` that was never initialized | Initialize every assign in `mount/3` or `handle_params/3` before it is rendered |
| Subscribe to PubSub or start timers in the static mount | Guard side effects with `if connected?(socket)` |
| Query the database directly from the LiveView | Call context functions (e.g. `Posts.list_posts/0`) instead |
| Read an assign then re-assign it to increment | Use `update/3` to transform the current value |
| Use `@key` for an optional assign in a helper | Use `Map.get(assigns, :key, default)` to avoid `KeyError` |
| Return a bare socket or the wrong tuple from a callback | Return `{:ok, socket}` from `mount`, `{:noreply, socket}` from handlers |
| Omit `@impl true` on a callback | Add `@impl true` before `mount`, `handle_event`, `handle_info`, `handle_params` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | phoenix-liveview-essentials | liveview-streams |
| ecto-changeset-patterns | phoenix-liveview-essentials | phoenix-liveview-auth |

**Companion skills:** `liveview-streams`, `phoenix-scopes`, `phoenix-pubsub-patterns`, `testing-essentials`.
