---
name: phoenix-json-api
type: atomic
tags: [atomic]
license: MIT
description: >
  Handles Phoenix-specific JSON API construction end-to-end. Use when building or modifying Phoenix
  API controllers, router pipelines, FallbackController error handling, paginated list endpoints,
  URL-versioned API routes (/api/v1/), or Bearer token authentication plugs in an Elixir/Phoenix
  application. Covers the full workflow from route definition to structured JSON error responses.
  Trigger words: Phoenix JSON API, API pipeline, FallbackController, paginated API, Bearer token plug,

  API versioning, Elixir API controller, action_fallback.
---

# Phoenix JSON API

## RULES — Follow these with no exceptions

1. **Use the `:api` pipeline** — don't mix HTML and JSON pipelines; API routes skip CSRF and sessions
2. **Render errors as structured JSON** — `{:error, changeset}` must become `{"errors": {...}}`
3. **Version APIs via URL prefix (`/api/v1/`)** — not headers; URL versioning is visible and cacheable
4. **Use `FallbackController` for consistent error handling** — every action returns `{:ok, result}` or `{:error, reason}`


## Build Workflow

Follow these steps in order when constructing a new API endpoint:

1. **Define the route** in the `:api` (or `:api_auth`) pipeline scope with a versioned URL prefix
2. **Create the controller** with `action_fallback MyAppWeb.FallbackController` and return `{:ok, _}` / `{:error, _}` from every action
3. **Verify error responses** — confirm that invalid input and missing resources return structured JSON (e.g., `{"errors": {...}}`) before proceeding
4. **Add the auth plug** (`ApiAuth`) to protected scopes; confirm that missing/invalid tokens yield `401` with a JSON body
5. **Paginate list endpoints** — ensure `index` accepts `page`/`per_page` params and never returns an unbounded collection


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


## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | phoenix-json-api | testing-essentials |
| security-essentials | phoenix-json-api | req-http-client |
