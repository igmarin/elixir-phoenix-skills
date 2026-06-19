# LiveView Test Templates

## Full Page LiveView Test

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "Index" do
    test "mounts and lists posts", %{conn: conn} do
      post = post_fixture()

      {:ok, view, html} = live(conn, ~p"/posts")

      assert html =~ "Posts"
      assert html =~ post.title
      assert has_element?(view, "#posts-list")
    end

    test "handles delete event", %{conn: conn} do
      post = post_fixture()
      {:ok, view, _html} = live(conn, ~p"/posts")

      view
      |> element("#posts-#{post.id} button", "Delete")
      |> render_click()

      refute has_element?(view, "#posts-#{post.id}")
    end

    test "redirects unauthenticated users", %{conn: conn} do
      conn = delete_session(conn)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/posts")
      assert path == ~p"/users/log_in"
    end
  end

  describe "Form" do
    test "creates a post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      view
      |> form("#post-form", post: %{title: "Hello", body: "World"})
      |> render_submit()

      assert_redirect(view, ~p"/posts")
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/posts/new")

      html =
        view
        |> form("#post-form", post: %{title: "", body: ""})
        |> render_submit()

      assert html =~ "can't be blank"
    end
  end
end
```

## Isolated LiveComponent Test

```elixir
defmodule MyAppWeb.PostLive.FormComponentTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders form for new post" do
    changeset = MyApp.Blog.Post.changeset(%MyApp.Blog.Post{}, %{})

    {:ok, view, _html} =
      live_isolated(conn(), MyAppWeb.PostLive.FormComponent,
        session: %{"changeset" => changeset, "action" => :new}
      )

    assert has_element?(view, "#post-form")
    assert has_element?(view, "button", "Save")
  end

  test "validates and sends event on submit" do
    changeset = MyApp.Blog.Post.changeset(%MyApp.Blog.Post{}, %{})

    {:ok, view, _html} =
      live_isolated(conn(), MyAppWeb.PostLive.FormComponent,
        session: %{"changeset" => changeset, "action" => :new}
      )

    view
    |> form("#post-form", post: %{title: "Hello", body: "World"})
    |> render_submit()

    assert_redirect(view, "/posts")
  end
end
```
