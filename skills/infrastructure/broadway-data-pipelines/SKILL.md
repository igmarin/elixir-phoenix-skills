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

---

## End-to-End Setup Workflow

Follow these steps in order when building a new Broadway pipeline:

1. **Add dependencies** — add `broadway` (and any producer library) to `mix.exs`, then run `mix deps.get`
2. **Define the pipeline module** — implement `handle_message/3` and `handle_batch/4` callbacks
3. **Add to supervision tree** — include the pipeline module in `application.ex`
4. **Verify producer connectivity** — start the app and confirm the producer connects (check logs for errors)
5. **Test with a single message** — use `Broadway.Test` helpers before scaling concurrency
6. **Scale concurrency** — tune processor and batcher concurrency based on CPU cores and throughput targets
7. **Validate error handling** — intentionally send a bad message and confirm `handle_failed/2` fires correctly
8. **Enable observability** — wire up telemetry events and optionally add `broadway_dashboard`

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
    data = Enum.map(messages, & &1.data)
    MyApp.Repo.insert_all(MyApp.Record, data)
    messages
  end

  def handle_batch(:s3, messages, _, _) do
    Enum.each(messages, fn message ->
      S3.upload(message.data)
    end)
    messages
  end

  defp process_data(data) do
    Map.put(data, :processed_at, DateTime.utc_now())
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
    Enum.each(messages, fn message ->
      Logger.error("Message failed: #{inspect(message.data)}")
      DeadLetterQueue.send(message.data, message.status.reason)
    end)
    messages
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
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

## Custom Producers

Use a raw `GenStage` producer when Broadway's built-in producer modules don't fit your source (database polling, custom APIs, files).

```elixir
defmodule MyApp.CustomProducer do
  use GenStage

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  def init(_opts), do: {:producer, %{queue: :queue.new()}}

  @impl true
  def handle_demand(demand, state) when demand > 0 do
    messages = fetch_messages(demand)
    {:noreply, messages, state}
  end

  defp fetch_messages(count) do
    Enum.map(1..count, fn i -> %{id: i, data: "message_#{i}"} end)
  end
end
```

---

## Rate Limiting

```elixir
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
```

---

## Testing

Use `Broadway.Test` helpers to exercise message and batch handling without a live producer.

```elixir
defmodule MyApp.MessagePipelineTest do
  use ExUnit.Case
  import Broadway.Test

  test "processes messages successfully" do
    message = %Broadway.Message{data: %{id: 1, value: "test"}}
    [processed_message] = handle_message(MyApp.MessagePipeline, message)
    assert processed_message.data.processed_at
  end

  test "handles batch processing" do
    messages = [%Broadway.Message{data: %{id: 1}}, %Broadway.Message{data: %{id: 2}}]
    processed = handle_batch(MyApp.MessagePipeline, :default, messages)
    assert length(processed) == 2
  end
end
```

---

## LiveDashboard Integration

```elixir
# router.ex
live_dashboard "/dashboard",
  additional_pages: [
    broadway: {BroadwayDashboard, pipelines: [MyApp.MessagePipeline]}
  ]
```

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| otp-essentials | broadway-data-pipelines | testing-essentials |
