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
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
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
7. **Never use `auto_upload: true` with form submission** — use manual uploads instead
8. **Check `core_components.ex` for existing components** before creating custom ones
9. **Never query the database directly from LiveViews** — call context functions instead
10. **Use streams for large collections** — see `liveview-streams` skill for details

---

## Recommended Build Order

1. **Define `mount/3`** — initialize all assigns with static defaults
2. **Add `handle_params/3`** — set URL-dependent assigns, subscribe to PubSub
3. **Write `render/1`** — reference only assigns initialized in steps 1–2
4. **Add `handle_event/3`** — implement user interactions with proper error handling
5. **Verify static render** — confirm no `KeyError` before WebSocket connects

**Test templates:** copy-paste starting points live in the skill's assets —
[`assets/liveview_test_template.md`](assets/liveview_test_template.md) for full-page
`Phoenix.LiveViewTest` cases and [`assets/component_test_template.md`](assets/component_test_template.md)
for function-component tests.

---

## Critical Concept: Two-Phase Rendering

- **Phase 1 — Disconnected:** HTTP request; `connected?(socket)` is `false`; side effects won't work.
- **Phase 2 — Connected:** WebSocket established; `connected?(socket)` is `true`; events and live updates work.

Both phases run `mount` → `handle_params` → render. Initialize all assigns to safe defaults in Phase 1 so the static HTML never raises a `KeyError`.

---

## Mount Callback

```elixir
@impl true
def mount(_params, _session, socket) do
  # Initialize static defaults here; URL-dependent assigns go in handle_params
  socket =
    socket
    |> assign(:user, nil)
    |> assign(:loading, false)
    |> assign(:data, [])

  # Only subscribe when connected — avoids double subscriptions across both render phases
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
      assign(socket, :data, [])  # Placeholder for static render
    end

  {:ok, socket}
end
```

**✅ Validation checkpoint:** Verify all assigns used in render/1 are initialized — the static render must display without a `KeyError`.

---

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

---

## Handle Info

```elixir
@impl true
def handle_info({:post_created, post}, socket) do
  {:noreply, update(socket, :posts, fn posts -> [post | posts] end)}
end

@impl true
def handle_info(%{event: "presence_diff"}, socket) do
  {:noreply, assign(socket, :online_users, get_presence_count())}
end
```

---

## Handle Params

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

## Socket Assigns

Always produce a new socket with `assign/3`, `assign/2`, or `update/3` — never mutate `socket.assigns` in place.

❌ **Bad — mutating `socket.assigns` directly (won't compile / won't render):**
```elixir
def handle_info({:count_update, n}, socket) do
  socket.assigns[:count] = n
  {:noreply, socket}
end
```

✅ **Good — single `assign/3` returns a new socket:**
```elixir
socket = assign(socket, :count, 0)
```

✅ **Good — set multiple assigns in one call:**
```elixir
socket = assign(socket, count: 0, name: "User", active: true)
```

✅ **Good — use `update/3` for an incremental change to an existing assign:**
```elixir
socket = update(socket, :count, &(&1 + 1))
```

**Safe access in helper functions** — reading a maybe-missing key directly raises `KeyError`; use `Map.get/3` with a default:

❌ **Bad — directly reading a possibly-missing assign:**
```elixir
defp format_user(assigns) do
  assigns.current_user.name
end
```

✅ **Good — `Map.get(assigns, :optional_key, default)` for optional assigns:**
```elixir
defp format_user(assigns) do
  case Map.get(assigns, :current_user, nil) do
    nil -> "Guest"
    user -> user.name
  end
end
```

---

## Live Navigation

```elixir
# Full page reload (new LiveView)
{:noreply, push_navigate(socket, to: ~p"/users")}

# Patch (same LiveView, different params)
{:noreply, push_patch(socket, to: ~p"/posts/#{post}")}
```

---

## Components

```elixir
def card(assigns) do
  ~H"""
  <div class="card">
    <h3><%= @title %></h3>
    <p><%= @content %></p>
  </div>
  """
end

# Usage in template
# <.card title="Hello" content="World" />
```

---

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

---

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

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Omit `@impl true` on callbacks | Add `@impl true` before every `mount`/`handle_event`/`handle_info`/`handle_params` |
| Access an assign in `render/1` that was never initialized | Initialize every rendered assign in `mount/3` (or `handle_params/3`) |
| Subscribe/start timers on the static render | Guard side effects with `if connected?(socket)` |
| Mutate `socket.assigns` directly | Use `assign/2,3` or `update/3` to return a new socket |
| Read a maybe-missing assign with `assigns.key` in a helper | Use `Map.get(assigns, :key, default)` |
| Query `Repo` directly inside the LiveView | Call context functions (`Posts.list_posts/0`) |
| Nested `case` for multi-step fallible work | Use `with` and assign errors to the socket |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | phoenix-liveview-essentials | apply-phoenix-liveview-conventions |
| None (always first) | phoenix-liveview-essentials | liveview-streams |

**Companion skills:**
- `apply-phoenix-liveview-conventions` — enforce these patterns on new/changed LiveView code
- `liveview-streams` — efficient rendering for large collections (100+ items)
- `phoenix-pubsub-patterns` — real-time updates via PubSub subscriptions
- `phoenix-scopes` — scope-based authentication inside LiveViews
- `testing-essentials` — `Phoenix.LiveViewTest` coverage

---

See the `liveview-checklist` agent file for a step-by-step LiveView development checklist. Related skills: `liveview-streams`, `phoenix-pubsub-patterns`, `phoenix-liveview-auth`, `phoenix-scopes`, `testing-essentials`.

---

## When Not to Use

- **Static HTML pages without LiveView** — use standard Phoenix controller/view patterns instead
- **Large collection rendering (100+ items)** — use `liveview-streams` instead for DOM efficiency
- **File upload patterns** — use `phoenix-uploads` instead
