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

## RULES — Follow these with no exceptions

1. **Always authorize on the server in event handlers** — never rely on UI-only checks
2. **Verify resource ownership by comparing `current_scope.user.id` against the resource's `user_id`** — never trust client-sent user IDs
3. **Use policy modules for complex authorization** — don't inline permission checks in LiveViews or controllers
4. **Add `data-confirm` attribute for destructive UI actions** — client-side confirmation before server round-trip
5. **Test both authorized and unauthorized paths** — every `handle_event` that mutates data needs an authz test
6. **Scope queries to the current user in contexts** — `where(user_id: ^user_id)` prevents IDOR vulnerabilities

---

## Authorization Workflow for a New Resource

Follow these steps in order when adding authorization to any new resource:

1. **Add scoped queries in the context** — ensure all queries filter by `user_id` so unauthorized data is never returned
2. **Define policy module rules** — add clauses for every action (`view`, `edit`, `delete`, etc.) before wiring up any LiveView
3. **Add server-side checks in LiveView event handlers** — call `Policy.authorize/3` or compare `current_scope.user.id` against the resource's `user_id` in every `handle_event` that mutates data
4. **Write unauthorized-path tests first** — confirm that a non-owner receives an error and that the mutation does not occur
5. **Only then add UI controls** — hide or disable buttons for unauthorized users *after* server-side checks are verified

**Validation checkpoints:**
- Every context function that returns or mutates a resource is scoped to the current user ✓
- Policy module has a catch-all clause returning `{:error, :unauthorized}` ✓
- Every mutating `handle_event` has a corresponding unauthorized-path test ✓

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

## Related Skills

| Skill | Purpose |
|---|---|
| **phoenix-liveview-auth** | Authentication (who you are) |
| **phoenix-scopes** | Phoenix 1.8+ Scope-based auth |
| **testing-essentials** | Testing patterns |
| **security-essentials** | Broader security best practices |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| phoenix-liveview-essentials | phoenix-authorization-patterns | security-essentials |
