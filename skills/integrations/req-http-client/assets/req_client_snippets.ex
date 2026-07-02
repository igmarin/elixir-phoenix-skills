# Req HTTP Client Snippets
#
# Copy-paste templates for a configured Req base client and a thin wrapper module.
# Referencing modules such as Application/Req/Mint that are undefined here is fine —
# only the syntax of this file is checked.

defmodule MyApp.ApiClient do
  @moduledoc """
  A configured Req base client plus a thin wrapper around common calls.

  Build the request options once with `Req.new/1` (base_url, retry, timeouts,
  default headers, JSON decoding) and reuse the client for every call.
  """

  # Build the base client a single time and reuse it everywhere.
  def base_client do
    Req.new(
      base_url: Application.fetch_env!(:my_app, :api_base_url),
      headers: [{"authorization", "Bearer #{api_token()}"}],
      # Req decodes/encodes JSON by default; make the intent explicit.
      decode_json: [keys: :strings],
      receive_timeout: 30_000,
      # Retry idempotent requests on 5xx and network errors with backoff.
      retry: :transient,
      retry_delay: &retry_delay/1,
      max_retries: 3,
      retry_log_level: :warning
    )
  end

  # Exponential backoff: 1s, 2s, 4s, ...
  defp retry_delay(attempt), do: (2 ** attempt) * 1000

  @doc "Fetch a single user, mapping HTTP status to a domain result."
  def fetch_user(id) do
    base_client()
    |> Req.get(url: "/users/#{id}")
    |> handle_response()
  end

  @doc "Create a user by POSTing a JSON body."
  def create_user(attrs) when is_map(attrs) do
    base_client()
    |> Req.post(url: "/users", json: attrs)
    |> handle_response()
  end

  # Centralized status handling keeps each call site small.
  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404}}), do: {:error, :not_found}
  defp handle_response({:ok, %{status: 429}}), do: {:error, :rate_limited}

  defp handle_response({:ok, %{status: status}}) when status >= 500 do
    {:error, :server_error}
  end

  defp handle_response({:ok, %{status: status}}), do: {:error, {:unexpected_status, status}}
  defp handle_response({:error, %Mint.TransportError{reason: :timeout}}), do: {:error, :timeout}
  defp handle_response({:error, exception}), do: {:error, Exception.message(exception)}

  defp api_token, do: Application.fetch_env!(:my_app, :api_token)
end

defmodule MyApp.ApiClient.Streaming do
  @moduledoc "Stream large responses instead of loading them fully into memory."

  def download(url, path) do
    Req.get!(url, into: File.stream!(path))
  end

  def stream_with_callback(url) do
    Req.get!(url,
      into: fn {:data, data}, {req, resp} ->
        IO.puts("Received #{byte_size(data)} bytes")
        {:cont, {req, resp}}
      end
    )
  end
end
