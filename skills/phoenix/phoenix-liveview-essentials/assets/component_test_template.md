# LiveComponent Test Templates

## Stateless Component Test

```elixir
defmodule MyAppWeb.Components.ButtonTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders button with label" do
    assigns = %{label: "Click me"}

    html =
      rendered_to_string(~H"""
      <MyAppWeb.Components.button label={@label} />
      """)

    assert html =~ "Click me"
    assert html =~ "<button"
  end

  test "renders disabled button" do
    assigns = %{label: "Submit", disabled: true}

    html =
      rendered_to_string(~H"""
      <MyAppWeb.Components.button label={@label} disabled={@disabled} />
      """)

    assert html =~ "disabled"
  end
end
```

## Stateful Component Test (via parent LiveView)

```elixir
defmodule MyAppWeb.SearchComponentTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "searches and updates results", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search")

    view
    |> form("#search-form", search: %{query: "elixir"})
    |> render_change()

    assert has_element?(view, "#search-results")
    refute has_element?(view, ".no-results")
  end

  test "shows empty state when no results", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search")

    view
    |> form("#search-form", search: %{query: "xyznonexistent"})
    |> render_change()

    assert has_element?(view, ".no-results")
  end
end
```
