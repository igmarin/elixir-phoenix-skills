---
name: broadway-data-pipelines
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when building data processing pipelines or consuming message queues. Invoke before implementing
  GenStage or Broadway consumers. Covers Broadway setup, producers, processors, batchers, and error handling.
  Trigger words: Broadway, GenStage, data pipeline, message queue, consumer, producer, batcher, SQS, Kafka.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Broadway Data Pipelines

Broadway is a framework for building data ingestion and processing pipelines in Elixir.

## RULES — Follow these with no exceptions

1. **Use Broadway for data pipelines** — not raw GenStage, unless you need custom topology
2. **Define producers, processors, and batchers** — separate concerns clearly
3. **Handle failures gracefully** — use `:on_success` and `:on_failure` callbacks
4. **Configure concurrency carefully** — match processor count to CPU cores
5. **Use batchers for database writes** — batch inserts are much faster than individual inserts
6. **Test with `Broadway.Test`** — use the built-in test helpers
7. **Monitor pipeline health** — use telemetry events for observability

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:broadway, "~> 1.0"},
    {:broadway_dashboard, "~> 0.3"}  # Optional: LiveDashboard integration
  ]
end
```

---

## Basic Pipeline

```elixir
defmodule MyApp.MessagePipeline do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwaySQS.Producer, queue_url: System.get_env("SQS_QUEUE_URL")}
      ],
      processors: [
        default: [concurrency: 10]
      ],
      batchers: [
        default: [concurrency: 5, batch_size: 100, batch_timeout: 2000],
        s3: [concurrency: 2, batch_size: 50]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _context) do
    message
    |> Broadway.Message.update_data(&process_data/1)
    |> Broadway.Message.put_batcher(:default)
  rescue
    exception ->
      Broadway.Message.failed(message, exception)
  end

  @impl true
  def handle_batch(:default, messages, _, _) do
    # Batch insert into database
    data = Enum.map(messages, & &1.data)
    MyApp.Repo.insert_all(MyApp.Record, data)
    messages
  end

  def handle_batch(:s3, messages, _, _) do
    # Upload to S3
    Enum.each(messages, fn message ->
      S3.upload(message.data)
    end)
    messages
  end

  defp process_data(data) do
    # Transform data
    data
    |> Map.put(:processed_at, DateTime.utc_now())
  end
end
```

---

## Supervision Tree

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # ...
    MyApp.MessagePipeline
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

---

## Custom Producers

```elixir
defmodule MyApp.CustomProducer do
  use GenStage

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:producer, %{queue: :queue.new()}}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    # Fetch messages from your source
    messages = fetch_messages(demand)

    {:noreply, messages, state}
  end

  defp fetch_messages(count) do
    # Fetch from database, API, file, etc.
    Enum.map(1..count, fn i ->
      %{id: i, data: "message_#{i}"}
    end)
  end
end
```

---

## Error Handling

```elixir
defmodule MyApp.MessagePipeline do
  use Broadway

  @impl true
  def handle_message(_, message, _context) do
    case process(message.data) do
      {:ok, result} ->
        Broadway.Message.update_data(message, fn _ -> result end)

      {:error, reason} ->
        Broadway.Message.failed(message, reason)
    end
  end

  @impl true
  def handle_failed(messages, _context) do
    # Handle failed messages
    Enum.each(messages, fn message ->
      Logger.error("Message failed: #{inspect(message.data)}")

      # Send to dead letter queue
      DeadLetterQueue.send(message.data, message.status.reason)
    end)

    messages
  end

  @impl true
  def handle_batch(:default, messages, batch_info, context) do
    # Handle batch errors
    case batch_insert(messages) do
      :ok ->
        messages

      {:error, reason} ->
        Logger.error("Batch failed: #{inspect(reason)}")
        Enum.map(messages, &Broadway.Message.failed(&1, reason))
    end
  end
end
```

---

## Rate Limiting

```elixir
defmodule MyApp.RateLimitedPipeline do
  use Broadway

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {MyApp.Producer, []},
        rate_limiting: [
          allowed_messages: 100,
          interval: 1000  # 100 messages per second
        ]
      ],
      processors: [default: [concurrency: 10]],
      batchers: [default: [batch_size: 50]]
    )
  end
end
```

---

## Testing

```elixir
defmodule MyApp.MessagePipelineTest do
  use ExUnit.Case

  import Broadway.Test

  test "processes messages successfully" do
    message = %Broadway.Message{data: %{id: 1, value: "test"}}

    [processed_message] =
      handle_message(MyApp.MessagePipeline, message)

    assert processed_message.data.processed_at
  end

  test "handles batch processing" do
    messages = [
      %Broadway.Message{data: %{id: 1}},
      %Broadway.Message{data: %{id: 2}}
    ]

    processed = handle_batch(MyApp.MessagePipeline, :default, messages)

    assert length(processed) == 2
  end
end
```

---

## LiveDashboard Integration

```elixir
# router.ex
import BroadwayDashboard

scope "/" do
  pipe_through :browser

  live_dashboard "/dashboard",
    additional_pages: [
      broadway: {BroadwayDashboard, pipelines: [MyApp.MessagePipeline]}
    ]
end
```

---

## Common Pitfalls

❌ **Don't** use raw GenStage unless you need custom topology
❌ **Don't** set processor concurrency too high — match CPU cores
❌ **Don't** skip error handling — messages will be lost
❌ **Don't** do database writes in processors — use batchers
❌ **Don't** forget to add pipeline to supervision tree

✅ **Do** use Broadway for data pipelines
✅ **Do** separate processors and batchers
✅ **Do** handle failures with `handle_failed`
✅ **Do** use batchers for database writes
✅ **Do** monitor with telemetry and LiveDashboard

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **oban-essentials** | When choosing between Oban and Broadway |
| **otp-essentials** | For understanding GenStage/OTP patterns |
| **telemetry-essentials** | For pipeline observability |
