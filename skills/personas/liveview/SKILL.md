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

Orchestrates full LiveView feature development from contract definition through testing and quality gates.

## Agent Phases

### Phase 1: Context & Contract

**Steps:**
1. Define the LiveView's purpose and URL (via `live "/path"` in router).
2. Define the `mount/3` contract: which params it receives, what session data it needs, what assigns it sets.
3. Define the assigns shape — what data the template will reference.

**HARD GATE — Contract Defined:**
- [ ] LiveView name and module path defined
- [ ] Route pattern defined
- [ ] mount/3 params and session documented
- [ ] Assigns shape documented (including streams if using collections)
- [ ] Events (handle_event, handle_info, handle_params) listed

**If gate fails:** Clarify the LiveView's purpose and data needs before coding.

---

### Phase 2: Test Design

**Steps:**
1. **testing/testing-essentials** — Choose test approach:
   - `live_isolated` for component-level tests
   - `live/2` (LiveViewTest) for full-page tests
   - Unit tests for helper functions
2. Write test covering: mount renders, key assigns present, events update socket, streams for collections.

**HARD GATE — Test Fails:**
- [ ] Test EXISTS and is written
- [ ] `mix test test/my_app_web/live/my_live_test.exs` FAILS
- [ ] Failure is for the correct reason (module not defined)

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

**Steps:**
1. **phoenix/phoenix-liveview-essentials** — Implement `mount/3` with proper assigns initialization.
2. Implement `render/1` with HEEx template.
3. Implement `handle_event/3` for user interactions.
4. Use **phoenix/liveview-streams** for any collection with >10 items.
5. Use **phoenix/phoenix-scopes** for authentication (Phoenix 1.8+) or **auth/phoenix-liveview-auth** (Phoenix 1.7).

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
- [ ] mount/3 implemented and sets all declared assigns
- [ ] render/1 implemented with HEEx template
- [ ] Events handled (handle_event, handle_info as needed)
- [ ] Streams used for collections >10 items
- [ ] Bracket access `assigns[:key]` for nullable assigns in templates

---

### Phase 4: Quality Gate

**Steps:**
1. Run focused test: `mix test test/my_app_web/live/my_live_test.exs` — must PASS.
2. Run full suite: `mix test` — must PASS.
3. Apply **quality/code-quality** for LiveView-specific checks.

**LiveView Quality Checklist:**
- [ ] No computed assigns in render (compute in mount/handle_event, assign result)
- [ ] Collections >10 items use `stream/3` not for-comprehension
- [ ] `phx-update="stream"` on stream containers
- [ ] Bracket access for nullable assigns
- [ ] Events have `phx-value-*` for data passing (not embedded JS)
- [ ] No `handle_info` interfering with streams
- [ ] `@impl true` on all callbacks

---

## Output Style

When completing a LiveView feature, output MUST include:

```markdown
# LiveView Report — [LiveView Name]

## Contract
- Module: <module path>
- Route: <live URL pattern>
- mount/3: <params>, <session>, assigns: <list>

## Test
- File: <test path>
- Approach: live / live_isolated / unit
- RED: <initial failure message>
- GREEN: <test passes>

## Implementation
- Template: <HEEx file path>
- Events: <list of handle_event/3 handlers>
- Streams: <list of stream names and collection sizes>
- Auth: Scope / current_user / anonymous

## Quality Gate
- mix test: ✓ (<n> tests, 0 failures)
- Streams used for >10 items: ✓
- Bracket access for nullables: ✓
- @impl true on callbacks: ✓
```

---

## Error Recovery

**LiveView fails to mount (LiveView test timeout):**
1. Check the route — does the LiveView mount?
2. Verify `mount/3` returns `{:ok, socket}` (not a halt or redirect if unintended).
3. Check assigns access in template — missing assigns cause crash.

**Stream rendering shows blank:**
1. Verify `phx-update="stream"` is on the container element.
2. Verify `id={dom_id}` is on each stream item.
3. Check that the stream name matches between `stream/3` and `@streams.name`.

**Event not triggering:**
1. Verify `phx-click="event_name"` matches `handle_event("event_name", ...)` exactly.
2. Check `phx-value-*` bindings are strings (they're always sent as strings).
3. Verify the element is inside the LiveView's DOM (not in a nested layout).

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|--------------|----------|
| elixir-skill-router | liveview | tdd |
| phoenix-liveview-essentials | liveview | quality |
| None (standalone) | liveview | PR submission |

**Use `phoenix-liveview-essentials` alone** if you only need LiveView patterns and conventions.

**Use `liveview` persona** for full feature development from contract to quality gate.
