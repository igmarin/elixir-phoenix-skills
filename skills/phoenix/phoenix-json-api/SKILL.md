---
name: phoenix-json-api
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY for ALL JSON API work. Invoke before writing API controllers, pipelines, or JSON responses.
  Covers API pipeline setup, controller patterns, FallbackController, pagination, versioning,
  Bearer token authentication, and error rendering.
  Trigger words: JSON API, API controller, FallbackController, pagination, Bearer token, API versioning.
metadata:
  user-invocable: "true"
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Phoenix JSON API

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY JSON API code.

## RULES — Follow these with no exceptions

1. **Use the `:api` pipeline** — don't mix HTML and JSON pipelines; API routes skip CSRF and sessions
2. **Render errors as structured JSON** — `{:error, changeset}` must become `{"errors": {...}}`
3. **Use offset/limit for pagination** — never return unbounded collections; default to a sensible limit
4. **Version APIs via URL prefix (`/api/v1/`)** — not headers; URL versioning is visible and cacheable
5. **Use `FallbackController` for consistent error handling** — every action returns `{:ok, result}` or `{:error, reason}`
6. **Authenticate via Bearer tokens in `Authorization` header** — not cookies
7. **Use `json/2` helper** — ensures `Content-Type: application/json`

---

## API Pipeline Setup

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug MyAppWeb.Plugs.ApiAuth
  end

  # Public endpoints
  scope "/api/v1", MyAppWeb.API.V1, as: :api_v1 do
    pipe_through :api

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
  end

  # Protected endpoints
  scope "/api/v1", MyAppWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    resources "/posts", PostController, except: [:new, :edit]
  end
end
```

---

## Controller Pattern

```elixir
defmodule MyAppWeb.API.V1.PostController do
  use MyAppWeb, :controller

  alias MyApp.Blog
  alias MyApp.Blog.Post

  action_fallback MyAppWeb.FallbackController

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "20") |> String.to_integer() |> min(100)

    {posts, total} = Blog.list_posts(page: page, per_page: per_page)

    conn
    |> put_resp_header("x-total-count", to_string(total))
    |> json(%{
      data: Enum.map(posts, &post_json/1),
      meta: %{page: page, per_page: per_page, total: total}
    })
  end

  def create(conn, %{"post" => post_params}) do
    with {:ok, %Post{} = post} <- Blog.create_post(post_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/posts/#{post}")
      |> json(%{data: post_json(post)})
    end
  end

  defp post_json(post) do
    %{
      id: post.id,
      title: post.title,
      body: post.body,
      inserted_at: post.inserted_at
    }
  end
end
```

---

## FallbackController

```elixir
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "Resource not found"}})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "Not authorized"}})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: format_changeset_errors(changeset)})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

---

## Bearer Token Authentication

```elixir
defmodule MyAppWeb.Plugs.ApiAuth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- MyApp.Accounts.get_user_by_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid or missing token"}})
        |> halt()
    end
  end
end
```

---

## Common Pitfalls

❌ **Don't** mix HTML and JSON pipelines
❌ **Don't** return unbounded collections — always paginate
❌ **Don't** use header-based API versioning
❌ **Don't** return raw changeset errors — format them
❌ **Don't** use cookies for API auth — use Bearer tokens

✅ **Do** use the `:api` pipeline
✅ **Do** use `FallbackController` for error handling
✅ **Do** paginate all list endpoints
✅ **Do** version APIs via URL prefix
✅ **Do** use Bearer tokens for authentication

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **security-essentials** | For token handling and input validation |
| **testing-essentials** | For API testing patterns |
| **req-http-client** | For making HTTP requests from Elixir |
