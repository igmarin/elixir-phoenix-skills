---
name: testing-essentials
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL test files. Invoke before writing any _test.exs file.
  Covers DataCase/ConnCase setup, fixture patterns, LiveView tests, changeset tests,
  async safety, setup chaining, timestamp testing, and TDD workflow.
  Trigger words: test, mix test, DataCase, ConnCase, fixture, LiveView test, assert, ExUnit.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Testing Essentials

## RULES — Follow these with no exceptions

1. **Follow the project's existing test setup patterns** — don't inline DataCase/ConnCase boilerplate that the project already abstracts away
2. **Use `async: true` only when safe** — avoid for DB contexts with shared rows, LiveView, `Application.put_env`, and external services
3. **Define test data in fixtures** (`test/support/`) — never build it inline across multiple tests
4. **Use `has_element?/2` and `element/2` for LiveView assertions** — not `html =~ "text"` for structure checks
5. **Always test the unauthorized case** for any protected resource
6. **Never hardcode dates** — use relative timestamps to prevent flaky tests

---

## Workflow: Writing a New Test File

Follow these steps in order, with explicit validation at each checkpoint:

1. **Check existing fixtures** — inspect `test/support/fixtures/` for relevant fixtures before creating new ones
2. **Create fixture if needed** — add to the appropriate fixtures module (see Fixture Pattern below)
3. **Verify compilation** — run `mix test` to confirm the fixture compiles before writing any tests
4. **Write the failing test** — implement the test case; run `mix test path/to/file_test.exs` and confirm it fails with a meaningful message (not a compile error)
5. **Verify the failure message** — the failure should describe a missing behaviour, not a setup problem
6. **Implement the feature**
7. **Verify the test passes** — re-run `mix test path/to/file_test.exs` and confirm green

See [`assets/tdd_checklist.md`](assets/tdd_checklist.md) for the full RED → GREEN → REFACTOR checklist and pre-commit quality gate.

---

## Test Module Setup

### DataCase — for context and schema tests

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true

  alias MyApp.Accounts
  import MyApp.AccountsFixtures
end
```

### ConnCase — for LiveView and controller tests

```elixir
defmodule MyAppWeb.UserLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MyApp.AccountsFixtures
end
```

See [`assets/spec_templates.md`](assets/spec_templates.md) for copy-paste DataCase, ConnCase, isolated LiveView, and ChannelCase test templates.

---

## Fixture Pattern

Define all test data in `test/support/fixtures/`:

```elixir
defmodule MyApp.AccountsFixtures do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user#{System.unique_integer([:positive])}@example.com",
        password: "hello world!"
      })
      |> MyApp.Accounts.register_user()

    user
  end
end
```

---

## Context Test Skeleton

```elixir
describe "create_post/1" do
  test "with valid attrs creates a post" do
    assert {:ok, %Post{} = post} = Blog.create_post(%{title: "Hello"})
    assert post.title == "Hello"
  end

  test "with invalid attrs returns error changeset" do
    assert {:error, %Ecto.Changeset{} = changeset} = Blog.create_post(%{})
    assert %{title: ["can't be blank"]} = errors_on(changeset)
  end
end
```

---

## LiveView Test Skeleton

```elixir
describe "index" do
  test "lists posts", %{conn: conn} do
    post = post_fixture()
    {:ok, _lv, html} = live(conn, ~p"/posts")
    assert html =~ post.title
  end

  test "unauthorized user is redirected", %{conn: conn} do
    {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/posts")
    assert path == ~p"/login"
  end
end

describe "create" do
  test "saves post with valid attrs", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/posts/new")

    lv
    |> form("#post-form", post: %{title: "New Post"})
    |> render_submit()

    assert has_element?(lv, "p", "Post created")
  end

  test "shows errors with invalid attrs", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/posts/new")

    lv
    |> form("#post-form", post: %{title: ""})
    |> render_submit()

    assert has_element?(lv, "p.alert", "can't be blank")
  end
end
```

---

## Changeset Test Skeleton

```elixir
describe "changeset/2" do
  test "valid attrs" do
    assert %Ecto.Changeset{valid?: true} = Post.changeset(%Post{}, %{title: "Hello"})
  end

  test "requires title" do
    changeset = Post.changeset(%Post{}, %{})
    assert %{title: ["can't be blank"]} = errors_on(changeset)
  end
end
```

---

## Setup Chaining

Use `setup [:func1, :func2]` to compose reusable setup functions; later functions receive assigns from earlier ones.

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  import MyApp.AccountsFixtures
  import MyApp.BlogFixtures

  setup [:register_and_log_in_user, :create_post]

  test "owner can edit post", %{conn: conn, post: post} do
    {:ok, lv, _html} = live(conn, ~p"/posts/#{post}/edit")
    assert has_element?(lv, "#post-form")
  end

  defp create_post(%{user: user}) do
    %{post: post_fixture(user_id: user.id)}
  end
end
```

---

## Timestamp Testing

❌ **Bad — hardcoded date will eventually be in the past:**
```elixir
assert post.published_at == ~U[2026-01-15 12:00:00Z]
```

✅ **Good — relative to now:**
```elixir
now = DateTime.utc_now(:second)
assert DateTime.diff(post.inserted_at, now, :second) < 5
```

✅ **Good — build relative dates for filtering/sorting:**
```elixir
past = DateTime.add(DateTime.utc_now(:second), -7, :day)
future = DateTime.add(DateTime.utc_now(:second), 7, :day)
old_post = post_fixture(published_at: past)
new_post = post_fixture(published_at: future)
assert Blog.list_published_posts() == [old_post]
```

---

## Troubleshooting Common Failures

- **Sandbox ownership errors** (`ownership timeout` or `DBConnection.OwnershipError`): flip the test to `async: false`.
- **LiveView sandbox errors** (`cannot find ownership process`): LiveView tests must use `async: false`.
- **`Application.put_env` leaking between tests**: restore in an `on_exit` callback and use `async: false`.
- **Flaky timestamp assertions**: replace hardcoded datetimes with `DateTime.diff/3` comparisons (see Timestamp Testing above).
- **Unexpected redirect in LiveView**: confirm the test user has the required role/session via `register_and_log_in_user` setup.

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Run LiveView tests with `async: true` | Use `async: false` for LiveView tests (sandbox ownership) |
| Assert structure with `html =~ "text"` | Use `has_element?/2` and `element/2` for structural checks |
| Inline the same test data across many tests | Define reusable `*_fixture/1` helpers in `test/support/fixtures/` |
| Assert against hardcoded datetimes | Compare relative to `DateTime.utc_now/1` with `DateTime.diff/3` |
| Test only the happy path for protected resources | Always assert the unauthorized/redirect case too |
| Call `Repo` directly in test setup | Build state through context functions and fixtures |
| Leave `Application.put_env` changes unrestored | Restore in `on_exit` and mark the test `async: false` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| ecto-essentials | testing-essentials | property-based-testing |
| phoenix-liveview-essentials | testing-essentials | benchee-profiling |

**Companion skills:**
- `tdd` — persona that drives the RED → GREEN → REFACTOR loop
- `property-based-testing` — generator-driven invariants for edge-case coverage
- `benchee-profiling` — performance benchmarking once behaviour is verified

---

See `agents/testing-guide.md` for comprehensive examples covering async tests, Mox mocking, file upload testing, and Ecto query testing.
