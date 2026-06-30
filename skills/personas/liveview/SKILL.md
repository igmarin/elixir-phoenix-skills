---
name: liveview
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates LiveView feature development with hard gates: define mount/3 contract and assigns shape → write failing LiveView test using live_isolated or live/2 → implement mount, handle_event, and render with streams for collections → verify full LiveView lifecycle (mount→render→event→update) → quality gate (no assigns bloat, streams for >10 items, bracket access in templates); phases context→test design→implementation→quality. Use when building a new LiveView, adding features to an existing LiveView, or refactoring LiveView code. Trigger: create LiveView, new LiveView page, add LiveView feature, LiveView component, LiveView event, handle_event, mount.
# LiveView Persona

### Phase 1: Context & Contract

1. Define the LiveView's purpose and URL (via `live "/path"` in router).
2. Define the `mount/3` contract: which params and session keys are used, what assigns are set.
3. List every assigns key the template will reference, including streams for collections.
4. List all events (`handle_event`, `handle_info`, `handle_params`) this LiveView must handle.

**HARD GATE — Contract Defined:**
- [ ] Module name, file path, and route pattern decided
- [ ] Assigns shape documented (keys, types, streams if applicable)
- [ ] All events listed

---

### Phase 2: Test Design

1. Choose test approach:
   - `live_isolated` for component-level tests
   - `live/2` (LiveViewTest) for full-page tests
2. Write tests covering: mount renders, key assigns present, events update socket, streams for collections.
3. Verify the test **FAILS** with `mix test test/my_app_web/live/my_live_test.exs` — failure must be confirmed before moving to implementation.

**Sample test skeleton:**

```elixir
defmodule MyAppWeb.ItemLiveTest do
  use MyAppWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "mounts and renders item list", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/items")
    assert html =~ "Items"
    assert has_element?(lv, "[data-role=item-list]")
  end

  test "adding an item updates the stream", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/items")
    lv |> form("#item-form", item: %{name: "Widget"}) |> render_submit()
    assert has_element?(lv, "[data-role=item-list]", "Widget")
  end
end
```

**HARD GATE — Test Fails:**
- [ ] Test file exists and covers mount, key assigns, and at least one event
- [ ] `mix test` confirms tests fail (module not yet implemented)

---

### Phase 3: Implementation

1. Implement `mount/3`: assign all documented keys; use `stream/3` for collections (see stream rule in Phase 4 Quality Gate).
2. Implement `handle_event/3` for each listed event; update socket with `assign/2` or `stream_insert/3`.
3. Implement `render/1` (or `.html.heex` template): use dot access (`@key`) for assigns guaranteed by `mount/3`; bracket access (`assigns[:key]`) only for keys that may be absent.

**Minimal LiveView module:**

```elixir
defmodule MyAppWeb.ItemLive do
  use MyAppWeb, :live_view

  alias MyApp.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Items")
     |> assign(:form, to_form(Catalog.change_item(%Catalog.Item{})))
     |> stream(:items, Catalog.list_items())}
  end

  @impl true
  def handle_event("save", %{"item" => item_params}, socket) do
    case Catalog.create_item(item_params) do
      {:ok, item} ->
        {:noreply, stream_insert(socket, :items, item)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1><%= @page_title %></h1>
    <.form for={@form} id="item-form" phx-submit="save">
      <.input field={@form[:name]} label="Name" />
      <.button>Save</.button>
    </.form>
    <ul id="items" phx-update="stream" data-role="item-list">
      <li :for={{dom_id, item} <- @streams.items} id={dom_id}>
        <%= item.name %>
      </li>
    </ul>
    """
  end
end
```

**HARD GATE — Implementation Complete:**
- [ ] `mount/3` sets all documented assigns and streams
- [ ] All listed events implemented
- [ ] Stream containers use `phx-update="stream"`
- [ ] `mix test` passes

---

### Phase 4: Quality Gate

Run these checks before considering the LiveView done.

**Stream rule — use streams for any collection that may exceed 10 items:**

```elixir
# ❌ assigns bloat
assign(socket, :items, Catalog.list_items())

# ✅ correct
stream(socket, :items, Catalog.list_items())
```

**Template access rule — dot access for guaranteed assigns, bracket access for optional keys:**

```heex
<%# ✅ dot access — guaranteed by mount/3 %>
<%= @user.name %>

<%# ✅ bracket access — optional keys %>
<%= @user[:name] %>
```

**Quality gate checklist:**
- [ ] No raw list assigns for collections >10 items — all use streams with `phx-update="stream"`
- [ ] Dot access for guaranteed assigns; bracket access only for optional keys
- [ ] No business logic in `render/1` — all data preparation in `mount/3` or event handlers
- [ ] `handle_event` clauses return `{:noreply, socket}` (or `{:reply, map, socket}`)
- [ ] LiveView has a focused purpose — if assigns exceeds ~8 keys, consider extracting a component
- [ ] `mix test` passes with no compiler warnings

**HARD GATE — Quality Gate Passes:**
- [ ] All checklist items above confirmed
- [ ] No compiler warnings related to the new LiveView module
- [ ] Peer review or self-review of assigns shape against original contract (Phase 1)
