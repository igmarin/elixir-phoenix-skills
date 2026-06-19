---
name: phoenix-authorization-patterns
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL authorization and access control work. Invoke before writing permission checks,
  policy modules, or role-based access. Covers server-side authorization, owner-only patterns,
  scoped queries, policy modules, controller authorization, and testing.
  Trigger words: authorization, access control, permission, policy, role, owner, scoped query, IDOR.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix Authorization Patterns

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY authorization or access control code.

## RULES — Follow these with no exceptions

1. **Always authorize on the server in event handlers** — UI-only checks (hiding buttons) are not security
2. **Verify resource ownership by comparing `current_scope.user.id` against the resource's `user_id`** — never trust client-sent user IDs
3. **Use policy modules for complex authorization** — don't inline permission checks in LiveViews or controllers
4. **Add `data-confirm` attribute for destructive UI actions** — client-side confirmation before server round-trip
5. **Test both authorized and unauthorized paths** — every `handle_event` that mutates data needs an authz test
6. **Scope queries to the current user in contexts** — `where(user_id: ^user_id)` prevents IDOR vulnerabilities

---

## Server-Side Authorization in LiveViews

```elixir
defmodule MyAppWeb.PostLive.Show do
  use MyAppWeb, :live_view

  @impl true
  def handle_event("delete", _params, socket) do
    post = socket.assigns.post

    if socket.assigns.current_scope.user.id == post.user_id do
      {:ok, _} = Blog.delete_post(post)
      {:noreply, push_navigate(socket, to: ~p"/posts")}
    else
      {:noreply, put_flash(socket, :error, "Not authorized")}
    end
  end
end
```

---

## Scoped Queries in Contexts

The strongest authorization pattern: queries only return data the user owns.

```elixir
defmodule MyApp.Blog do
  import Ecto.Query

  # Scoped — only returns posts owned by this user
  def list_user_posts(%Scope{user: user}) do
    Post
    |> where(user_id: ^user.id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  # Scoped get — returns nil if not owned by user
  def get_user_post(%Scope{user: user}, id) do
    Post
    |> where(user_id: ^user.id)
    |> Repo.get(id)
  end

  # Scoped update — only updates if owned
  def update_user_post(%Scope{user: user}, %Post{} = post, attrs) do
    if post.user_id == user.id do
      post |> Post.changeset(attrs) |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end
end
```

---

## Policy Modules

For complex permissions (roles, teams, org-level access):

```elixir
defmodule MyApp.Policy do
  alias MyApp.Accounts.User
  alias MyApp.Blog.Post

  def authorize(%User{role: :admin}, _action, _resource), do: :ok

  def authorize(%User{id: user_id}, :edit, %Post{user_id: user_id}), do: :ok
  def authorize(%User{id: user_id}, :delete, %Post{user_id: user_id}), do: :ok
  def authorize(%User{}, :view, %Post{published: true}), do: :ok

  def authorize(_user, _action, _resource), do: {:error, :unauthorized}
end

# Usage in LiveView
case Policy.authorize(user, :delete, post) do
  :ok -> {:ok, _} = Blog.delete_post(post)
  {:error, :unauthorized} -> put_flash(socket, :error, "Not authorized")
end
```

---

## Testing Authorization

```elixir
describe "authorization" do
  test "owner can delete their post", %{conn: conn} do
    user = user_fixture()
    post = post_fixture(user_id: user.id)
    conn = log_in_user(conn, user)

    {:ok, lv, _html} = live(conn, ~p"/posts/#{post}")
    lv |> element("button", "Delete") |> render_click()
    assert_redirect(lv, ~p"/posts")
  end

  test "non-owner cannot delete post", %{conn: conn} do
    owner = user_fixture()
    other_user = user_fixture()
    post = post_fixture(user_id: owner.id)
    conn = log_in_user(conn, other_user)

    {:ok, lv, _html} = live(conn, ~p"/posts/#{post}")
    refute render(lv) =~ "Delete"
    assert render_click(lv, "delete") =~ "Not authorized"
  end
end
```

---

## Common Pitfalls

❌ **Don't** rely on UI-only checks (hiding buttons)
❌ **Don't** trust client-sent user IDs
❌ **Don't** inline complex permission checks in LiveViews
❌ **Don't** forget to test unauthorized paths
❌ **Don't** forget `data-confirm` on destructive actions

✅ **Do** always authorize on the server
✅ **Do** use scoped queries to prevent IDOR
✅ **Do** use policy modules for complex permissions
✅ **Do** test both authorized and unauthorized paths
✅ **Do** add `data-confirm` for destructive actions

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-liveview-auth** | For authentication (who you are) |
| **phoenix-scopes** | For Phoenix 1.8+ Scope-based auth |
| **testing-essentials** | For testing patterns |
| **security-essentials** | For security best practices |
