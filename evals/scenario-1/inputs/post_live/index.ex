defmodule MyAppWeb.PostLive.Index do
  use MyAppWeb, :live_view

  alias MyApp.Blog

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    posts = Blog.list_posts(user_id)
    {:ok, assign(socket, posts: posts, page_title: "My Posts")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Blog.get_post_for_user(id, user_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found or access denied")}

      post ->
        {:ok, _} = Blog.delete_post(post)
        posts = Blog.list_posts(user_id)
        {:noreply, assign(socket, posts: posts)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="posts" class="posts-list">
      <h1>My Posts</h1>
      <%= for post <- @posts do %>
        <div id={"post-#{post.id}"} class="post-item">
          <h2><%= post.title %></h2>
          <p><%= post.body %></p>
          <button phx-click="delete" phx-value-id={post.id}>Delete</button>
        </div>
      <% end %>
    </div>
    """
  end
end
