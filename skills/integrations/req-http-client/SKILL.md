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

---

# Req HTTP Client

**Sections:** [RULES](#rules--follow-these-with-no-exceptions) · [End-to-End Workflow](#end-to-end-workflow) · [Quick-Reference: Request Types](#quick-reference-request-types) · [Retries](#retries) · [Streaming Responses](#streaming-responses) · [Common Pitfalls](#common-pitfalls) · [Integration](#integration)

---

## RULES — Follow these with no exceptions

1. **Always build a configured base client with `Req.new/1`** — set `base_url`, `receive_timeout`, and default headers once, then reuse it for every call instead of re-passing options
2. **Use the non-bang `Req.get/1` / `Req.post/1` in application code** — pattern match `{:ok, %{status: _, body: _}}` / `{:error, _}`; reserve the `!` variants for scripts and tests
3. **Match status codes explicitly** — handle `404`, `429`, and `status >= 500` distinctly; never collapse every non-200 into one branch
4. **Enable `retry: :transient` only for idempotent requests** — Req retries 5xx and network errors with backoff; never blindly retry non-idempotent writes
5. **Set an explicit `receive_timeout`** — never rely on infinite defaults for calls to external services
6. **Stub every external call in tests with `Req.Test`** — the suite must never hit a real API
7. **Stream large responses with `into:`** — write to `File.stream!/1` or a callback instead of loading the full payload into memory

See [`assets/req_client_snippets.ex`](assets/req_client_snippets.ex) for a copy-paste base client and wrapper module.


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


## Quick-Reference: Request Types

| Pattern | Example |
|---|---|
| GET | `Req.get!(url, params: %{page: 1})` |
| POST JSON | `Req.post!(url, json: %{name: "John"})` |
| POST form | `Req.post!(url, form: [username: "john", password: "secret"])` |
| With error handling | Use `Req.get/1` (not bang) and pattern match `{:ok, %{status: _, body: _}}` / `{:error, _}` |


## Retries

```elixir
# Automatic retries for transient failures
Req.get!("https://api.your-app.test/data",
  retry: :transient,           # Retry on 5xx and network errors
  retry_delay: &(&1 * 1000),   # Exponential backoff: 1s, 2s, 4s, ...
  max_retries: 3,              # Max 3 retries
  retry_log_level: :warning
)

# Custom retry logic (e.g. also retry on 429)
Req.get!("https://api.your-app.test/data",
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


## Streaming Responses

```elixir
# Stream large responses to a file
Req.get!("https://api.your-app.test/large-file",
  into: File.stream!("download.txt")
)

# Stream with a callback
Req.get!("https://api.your-app.test/stream",
  into: fn {:data, data}, {req, resp} ->
    IO.puts("Received #{byte_size(data)} bytes")
    {:cont, {req, resp}}
  end
)
```

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| `Req.get!` in app code and rescue exceptions | `Req.get/1` and pattern match `{:ok, _}` / `{:error, _}` |
| Rebuild `Req.new/1` options on every call | Build a base client once and reuse it |
| Treat any non-200 status the same | Match `404`, `429`, and `status >= 500` explicitly |
| `retry: :transient` on non-idempotent POSTs | Retry only idempotent requests; handle writes deliberately |
| Leave `receive_timeout` at the default | Set an explicit timeout for every external call |
| Hit the real API in the test suite | Stub with `Req.Test.stub/2` |
| Load a large response into memory | Stream with `into: File.stream!(path)` |
| Hardcode tokens in the client module | Read from `Application.get_env/2` / runtime config |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| elixir-essentials | req-http-client | testing-essentials |
| None (standalone) | req-http-client | oban-essentials |

**Companion skills:**
- `testing-essentials` — stub HTTP calls with `Req.Test` in the suite
- `oban-essentials` — retry and schedule outbound API calls in background jobs
- `cachex-caching` — cache responses from slow or rate-limited APIs
