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

**Sections:** [End-to-End Workflow](#end-to-end-workflow) · [Quick-Reference: Request Types](#quick-reference-request-types) · [Retries](#retries) · [Streaming Responses](#streaming-responses)

---

## End-to-End Workflow

Follow this sequence when integrating an external API:

**Step 1 — Add dependency**
```elixir
# mix.exs
defp deps do
  [
    {:req, "~> 0.5"}
  ]
end
```
Checkpoint: run `mix deps.get` and confirm Req compiles without errors.

**Step 2 — Create a configured client module**
```elixir
defmodule MyApp.ApiClient do
  def base_request do
    Req.new(
      base_url: Application.get_env(:my_app, :api_base_url),
      headers: [{"authorization", "Bearer #{api_token()}"}],
      receive_timeout: 30_000,
      retry: :transient
    )
  end

  def fetch_user(id) do
    case Req.get(base_request(), url: "/users/#{id}") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}}             -> {:error, :not_found}
      {:ok, %{status: 429}}             -> {:error, :rate_limited}   # extend with additional codes as needed
      {:ok, %{status: status}} when status >= 500 -> {:error, :server_error}
      {:ok, %{status: status}}          -> {:error, {:unexpected_status, status}}
      {:error, %Mint.TransportError{reason: :timeout}} -> {:error, :timeout}
      {:error, exception}               -> {:error, Exception.message(exception)}
    end
  end

  defp api_token, do: Application.get_env(:my_app, :api_token)
end
```
Checkpoint: verify the module compiles with `mix compile`.

**Step 3 — Test with Req.Test before touching a real API**
```elixir
defmodule MyApp.ApiClientTest do
  use ExUnit.Case, async: true

  setup do
    Req.Test.adapter(MyApp.ApiClient)
    :ok
  end

  test "fetches user successfully" do
    Req.Test.stub(MyApp.ApiClient, fn conn ->
      Req.Test.json(conn, %{"id" => 1, "name" => "John"})
    end)
    assert {:ok, %{"name" => "John"}} = MyApp.ApiClient.fetch_user(1)
  end

  test "handles not found" do
    Req.Test.stub(MyApp.ApiClient, fn conn ->
      conn |> Plug.Conn.put_status(404) |> Req.Test.json(%{"error" => "not found"})
    end)
    assert {:error, :not_found} = MyApp.ApiClient.fetch_user(999)
  end
end
```
Checkpoint: run `mix test` — all stubs must pass before using the real API.

**Step 4 — Verify in IEx against the real endpoint**
```elixir
iex> MyApp.ApiClient.fetch_user(1)
{:ok, %{"id" => 1, "name" => "John", ...}}
```
Checkpoint: confirm a `{:ok, body}` tuple is returned; check logs for retry warnings if the request is slow.

---

## Quick-Reference: Request Types

| Pattern | Example |
|---|---|
| GET | `Req.get!(url, params: %{page: 1})` |
| POST JSON | `Req.post!(url, json: %{name: "John"})` |
| POST form | `Req.post!(url, form: [username: "john", password: "secret"])` |
| With error handling | Use `Req.get/1` (not bang) and pattern match `{:ok, %{status: _, body: _}}` / `{:error, _}` |

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

# Custom retry logic (e.g. also retry on 429)
Req.get!("https://api.example.com/data",
  retry: fn response ->
    case response do
      %{status: 429} -> true
      %{status: s} when s >= 500 -> true
      _ -> false
    end
  end,
  max_retries: 3
)
```

---

## Streaming Responses

```elixir
# Stream large responses to a file
Req.get!("https://api.example.com/large-file",
  into: File.stream!("download.txt")
)

# Stream with a callback
Req.get!("https://api.example.com/stream",
  into: fn {:data, data}, {req, resp} ->
    IO.puts("Received #{byte_size(data)} bytes")
    {:cont, {req, resp}}
  end
)
```
