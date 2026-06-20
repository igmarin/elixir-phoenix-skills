---
name: liveview
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates LiveView feature development with hard gates: define mount/3 contract and assigns shape → write failing LiveView test using live_isolated or live/2 → implement mount, handle_event, and render with streams for collections → verify full LiveView lifecycle (mount→render→event→update) → quality gate (no assigns bloat, streams for >10 items, bracket access in templates); phases context→test design→implementation→quality. Use when building a new LiveView, adding features to an existing LiveView, or refactoring LiveView code. Trigger: create LiveView, new LiveView page, add LiveView feature, LiveView component, LiveView event, handle_event, mount.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when building new LiveView pages, adding LiveView features, or refactoring LiveView code"
  phases: "Phase 1: Context & Contract, Phase 2: Test Design, Phase 3: Implementation, Phase 4: Quality Gate"
  hard_gates: "Contract Defined, Test Fails, Implementation Complete, Quality Gate Passes"
  dependencies:
    - source: self
      skills: [phoenix-liveview-essentials, liveview-streams, phoenix-scopes, testing-essentials]
  keywords: elixir, phoenix, liveview, live_view, component, handle_event, mount, stream
---
# LiveView Persona

## Agent Phases

### Phase 1: Context & Contract

1. Define the LiveView's purpose and URL (via `live "/path"` in router).
2. Define the project-specific `mount/3` contract: which params and session keys this feature uses, what assigns it sets.
3. List the assigns shape — every key the template will reference, including streams for collections.
4. List all events (`handle_event`, `handle_info`, `handle_params`) this LiveView must handle.

**HARD GATE — Contract Defined:**
- [ ] Module name, file path, and route pattern decided
- [ ] Assigns shape documented (keys, types, streams if applicable)
- [ ] All events listed

**If gate fails:** Clarify the LiveView's purpose and data needs before coding.

---

### Phase 2: Test Design

1. Choose test approach:
   - `live_isolated` for component-level tests
   - `live/2` (LiveViewTest) for full-page tests
   - Unit tests for helper functions
2. Write test covering: mount renders, key assigns present, events update socket, streams for collections.
3. Verify the test **FAILS** with `mix test test/my_app_web/live/my_live_test.exs` — failure must be "module not defined".

**HARD GATE — Test Fails:**
- [ ] Test file exists and written
- [ ] `mix test` fails with "module not defined"

```elixir
# test/my_app_web/live/post_live_test.exs
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "mounts and renders posts", %{conn: conn} do
    post = post_fixture()
    {:ok, view, html} = live(conn, ~p"/posts")

    assert html =~ "Posts"
    assert html =~ post.title
    assert has_element?(view, "#posts-list")
  end
end
```

---

### Phase 3: Implementation

1. Implement `mount/3` — initialize all declared assigns; use `stream/3` for any collection with >10 items.
2. Implement `render/1` with HEEx template; use `assigns[:key]` bracket access for nullable assigns.
3. Implement `handle_event/3` (and `handle_info/2`, `handle_params/3` as needed).
4. For authentication: use Phoenix Scopes (Phoenix 1.8+) or `on_mount` hooks (Phoenix 1.7).

**Minimal implementation:**
```elixir
defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Blog

  @impl true
  def mount(_params, _session, socket) do
    posts = Blog.list_posts()

    {:ok,
     socket
     |> assign(:page_title, "Posts")
     |> stream(:posts, posts)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Blog.get_post!(id)
    {:ok, _} = Blog.delete_post(post)

    {:noreply, stream_delete(socket, :posts, post)}
  end
end
```

```heex
<!-- lib/my_app_web/live/post_live/index.html.heex -->
<h1><%= @page_title %></h1>

<div id="posts-list" phx-update="stream">
  <div :for={{dom_id, post} <- @streams.posts} id={dom_id}>
    <h2><%= post.title %></h2>
    <button phx-click="delete" phx-value-id={post.id}>Delete</button>
  </div>
</div>
```

**HARD GATE — Implementation Complete:**
- [ ] All assigns initialized in `mount/3`
- [ ] All events handled

---

### Phase 4: Quality Gate

1. Run focused test: `mix test test/my_app_web/live/my_live_test.exs` — must **PASS**.
2. Run full suite: `mix test` — must **PASS**.

**LiveView Quality Checklist:**
- [ ] No computed assigns in `render` (compute in `mount`/`handle_event`)
- [ ] Collections >10 items use `stream/3`, not for-comprehension assigns
- [ ] `phx-update="stream"` on containers; `id={dom_id}` on each item
- [ ] Bracket access (`assigns[:key]`) for nullable assigns in templates
- [ ] Events use `phx-value-*` for data passing
- [ ] `@impl true` on all callbacks

---

## Output Style

Report module path, route, test file (approach + RED→GREEN status), and quality gate results (streams compliance, bracket access, `@impl true` coverage).

---

## Error Recovery

**LiveView fails to mount (test timeout):**
1. Verify the route exists and `mount/3` returns `{:ok, socket}`.
2. Check template for missing assigns — unset assigns crash on render.

**Stream renders blank:**
1. Confirm `phx-update="stream"` is on the container and `id={dom_id}` on each item.
2. Confirm the stream name matches between `stream/3` and `@streams.name`.

**Event not triggering:**
1. Confirm `phx-click="event_name"` matches `handle_event("event_name", ...)` exactly.
2. Confirm `phx-value-*` bindings are strings and the element is inside the LiveView's DOM.
