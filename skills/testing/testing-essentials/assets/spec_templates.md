# ExUnit Test Templates

## Context Module Test (DataCase)

```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.Blog
  alias MyApp.Blog.Post

  describe "list_posts/0" do
    test "returns all posts ordered by inserted_at" do
      post1 = post_fixture(title: "First")
      post2 = post_fixture(title: "Second")

      assert Blog.list_posts() == [post2, post1]
    end

    test "returns empty list when no posts exist" do
      assert Blog.list_posts() == []
    end
  end

  describe "create_post/1" do
    test "creates a post with valid attrs" do
      attrs = %{title: "Hello", body: "World"}

      assert {:ok, %Post{} = post} = Blog.create_post(attrs)
      assert post.title == "Hello"
      assert post.body == "World"
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = Blog.create_post(%{title: nil})
    end
  end

  defp post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{title: "Test Post #{System.unique_integer()}", body: "Body"})
      |> Blog.create_post()

    post
  end
end
```

## LiveView Test (ConnCase)

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "mounts and renders posts", %{conn: conn} do
    post = post_fixture()

    {:ok, _view, html} = live(conn, ~p"/posts")

    assert html =~ "Posts"
    assert html =~ post.title
  end

  test "handles delete event", %{conn: conn} do
    post = post_fixture()
    {:ok, view, _html} = live(conn, ~p"/posts")

    assert view
           |> element("#posts-#{post.id} button", "Delete")
           |> render_click()

    refute has_element?(view, "#posts-#{post.id}")
  end
end
```

## LiveView Isolated Test

```elixir
defmodule MyAppWeb.PostLive.FormComponentTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders form with changeset", %{conn: conn} do
    {:ok, view, _html} =
      live_isolated(conn, MyAppWeb.PostLive.FormComponent,
        session: %{}
      )

    assert has_element?(view, "form")
  end
end
```

## Channel Test

```elixir
defmodule MyAppWeb.RoomChannelTest do
  use MyAppWeb.ChannelCase, async: true

  setup do
    {:ok, _, socket} =
      MyAppWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(MyAppWeb.RoomChannel, "room:lobby")

    %{socket: socket}
  end

  test "broadcasts messages to subscribers", %{socket: socket} do
    push(socket, "new_msg", %{"body" => "Hello"})

    assert_broadcast "new_msg", %{body: "Hello"}
  end
end
```
