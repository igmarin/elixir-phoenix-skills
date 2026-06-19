---
name: req-http-client
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when making HTTP requests from Elixir applications. Invoke before integrating external APIs.
  Covers Req setup, request patterns, error handling, retries, timeouts, and testing with Req.Test.
  Req is the modern HTTP client for Elixir, replacing HTTPoison and Tesla.
  Trigger words: Req, HTTP client, HTTP request, API integration, external API, HTTPoison replacement.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Req HTTP Client

Req is the modern HTTP client for Elixir, designed for simplicity and composability.

## RULES — Follow these with no exceptions

1. **Use Req for all HTTP requests** — the modern standard, replacing HTTPoison and Tesla
2. **Always handle error tuples** — `Req.get/1` returns `{:ok, response}` or `{:error, exception}`
3. **Set timeouts explicitly** — don't rely on defaults for production APIs
4. **Use retries for transient failures** — configure retry logic for 5xx and network errors
5. **Test with `Req.Test`** — use the built-in test adapter for mocking HTTP responses
6. **Parse JSON responses automatically** — use `Req.post(..., json: data)` and `decode_json: true`
7. **Never hardcode API URLs** — use configuration for base URLs and API keys

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:req, "~> 0.5"}
  ]
end
```

---

## Basic Requests

```elixir
# GET request
case Req.get("https://api.example.com/users") do
  {:ok, %{status: 200, body: body}} ->
    IO.inspect(body)

  {:ok, %{status: status}} ->
    IO.puts("Request failed with status: #{status}")

  {:error, exception} ->
    IO.puts("Request failed: #{Exception.message(exception)}")
end

# GET with query params
Req.get!("https://api.example.com/users", params: %{page: 1, per_page: 20})

# POST with JSON body
Req.post!("https://api.example.com/users",
  json: %{name: "John", email: "john@example.com"}
)

# POST with form data
Req.post!("https://api.example.com/login",
  form: [username: "john", password: "secret"]
)
```

---

## Configuration

```elixir
# Create a configured Req client
defmodule MyApp.ApiClient do
  def base_request do
    Req.new(
      base_url: "https://api.example.com",
      headers: [{"authorization", "Bearer #{api_token()}"}],
      receive_timeout: 30_000,
      retry: :transient,
      retry_delay: &(&1 * 1000)  # Exponential backoff
    )
  end

  def get_users do
    base_request()
    |> Req.get!(url: "/users", params: %{page: 1})
  end

  def create_user(attrs) do
    base_request()
    |> Req.post!(url: "/users", json: attrs)
  end

  defp api_token do
    Application.get_env(:my_app, :api_token)
  end
end
```

---

## Error Handling

```elixir
defmodule MyApp.ExternalApi do
  def fetch_user(id) do
    case Req.get("https://api.example.com/users/#{id}", receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status}} when status >= 500 ->
        {:error, :server_error}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end
end
```

---

## Retries

```elixir
# Automatic retries for transient failures
Req.get!("https://api.example.com/data",
  retry: :transient,           # Retry on 5xx and network errors
  retry_delay: &(&1 * 1000),   # Exponential backoff: 1s, 2s, 4s, ...
  max_retries: 3,              # Max 3 retries
  retry_log_level: :warning
)

# Custom retry logic
Req.get!("https://api.example.com/data",
  retry: fn response ->
    case response do
      %{status: 429} -> true  # Retry on rate limit
      %{status: s} when s >= 500 -> true  # Retry on server errors
      _ -> false
    end
  end,
  retry_delay: fn attempt ->
    # Wait 1s, 2s, 4s, 8s...
    :timer.seconds(:math.pow(2, attempt - 1) |> round())
  end
)
```

---

## JSON Handling

```elixir
# Automatic JSON decoding
{:ok, %{body: data}} = Req.get("https://api.example.com/users", decode_json: true)

# Send JSON body
{:ok, response} = Req.post("https://api.example.com/users",
  json: %{name: "John", email: "john@example.com"},
  decode_json: true
)

# Access decoded data
user = response.body
IO.puts(user["name"])
```

---

## Testing with Req.Test

```elixir
defmodule MyApp.ExternalApiTest do
  use ExUnit.Case, async: true

  setup do
    Req.Test.adapter(MyApp.ExternalApi)
    :ok
  end

  test "fetches user successfully" do
    Req.Test.stub(MyApp.ExternalApi, fn conn ->
      Req.Test.json(conn, %{
        "id" => 1,
        "name" => "John",
        "email" => "john@example.com"
      })
    end)

    assert {:ok, %{"name" => "John"}} = MyApp.ExternalApi.fetch_user(1)
  end

  test "handles not found" do
    Req.Test.stub(MyApp.ExternalApi, fn conn ->
      conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"error" => "not found"})
    end)

    assert {:error, :not_found} = MyApp.ExternalApi.fetch_user(999)
  end
end
```

---

## Streaming Responses

```elixir
# Stream large responses
Req.get!("https://api.example.com/large-file",
  into: File.stream!("download.txt")
)

# Stream with callback
Req.get!("https://api.example.com/stream",
  into: fn {:data, data}, {req, resp} ->
    IO.puts("Received #{byte_size(data)} bytes")
    {:cont, {req, resp}}
  end
)
```

---

## Common Pitfalls

❌ **Don't** use HTTPoison or Tesla — Req is the modern standard
❌ **Don't** forget to handle error tuples
❌ **Don't** rely on default timeouts for production
❌ **Don't** hardcode API URLs or keys
❌ **Don't** forget to configure retries for transient failures

✅ **Do** use Req for all HTTP requests
✅ **Do** handle both `{:ok, response}` and `{:error, exception}`
✅ **Do** set explicit timeouts
✅ **Do** use `Req.Test` for testing
✅ **Do** configure retries for production APIs

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-json-api** | When building JSON APIs that consume other APIs |
| **oban-essentials** | For async API calls |
| **testing-essentials** | For testing HTTP integrations |
