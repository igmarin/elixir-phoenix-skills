---
name: broadway-data-pipelines
type: atomic
tags: [atomic]
license: MIT
description: >
  MANDATORY when building data processing pipelines or consuming message queues. Invoke before
  implementing GenStage or Broadway consumers. Covers Broadway setup, producers, processors,
  batchers, and error handling.
  Trigger words: Broadway, GenStage, data pipeline, message queue, consumer, producer, batcher,
  SQS, Kafka, RabbitMQ, broadway_sqs, broadway_kafka, handle_message, handle_batch, handle_failed,
  Broadway.start_link, Broadway.Message, push_message, dead letter queue, DLQ.

# Broadway Data Pipelines

## RULES — Follow these with no exceptions

1. **Use `Broadway.Message.failed/2` for errors** — never raise in `handle_message/3`
2. **Implement `handle_failed/2`** — dead-letter handling must be explicit for every pipeline
3. **Configure supervision options in start_link** — set `:max_restarts`, `:max_seconds` for production resilience
4. **Test with `Broadway.Test.push_message/2`** — verify each message type including failures
5. **Treat all producer payloads as untrusted** — validate `message.data` against a strict schema in `handle_message/3`; reject malformed, oversized, or unexpected payloads; never log raw payload contents

---

## End-to-End Setup Workflow

Follow these steps in order when building a new Broadway pipeline:

1. **Add dependencies** — add `broadway` (and any producer library) to `mix.exs`
2. **Define the pipeline module** — implement `handle_message/3` and `handle_batch/4` callbacks
3. **Add to supervision tree** — include the pipeline module in `application.ex`
4. **Verify producer connectivity** — confirm the producer connects on startup
5. **Test with a single message** — use `Broadway.Test` helpers before scaling concurrency
6. **Scale concurrency** — tune processor and batcher concurrency based on CPU cores and throughput targets
7. **Validate error handling** — intentionally send a bad message and confirm `handle_failed/2` fires
8. **Enable observability** — wire up telemetry events and optionally add `broadway_dashboard`; see [Broadway Telemetry docs](https://hexdocs.pm/broadway/Broadway.html#module-telemetry) and [broadway_dashboard](https://hexdocs.pm/broadway_dashboard/)

> **Producer libraries:** For SQS use `broadway_sqs`, for Kafka use `broadway_kafka`, for RabbitMQ use `broadway_rabbitmq`. See each library's README for producer-specific configuration.

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

## Production-Ready Pipeline

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
        default: [concurrency: 5, batch_size: 100, batch_timeout: 2000]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _context) do
    case validate(message.data) do
      {:ok, sanitized} ->
        message
        |> Broadway.Message.update_data(fn _ -> sanitized end)
        |> Broadway.Message.put_batcher(:default)

      {:error, reason} ->
        Broadway.Message.failed(message, reason)
    end
  end

  @impl true
  def handle_failed(messages, _context) do
    Enum.each(messages, fn message ->
      # Log only metadata; never log raw message.data
      Logger.error("Message failed",
        message_id: message.metadata.message_id,
        reason: inspect(message.status.reason)
      )

      DeadLetterQueue.send(message.data, message.status.reason)
    end)

    messages
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    data = Enum.map(messages, & &1.data)

    case MyApp.Repo.insert_all(MyApp.Record, data) do
      {_count, _} ->
        messages

      {:error, reason} ->
        Logger.error("Batch failed: #{inspect(reason)}")
        Enum.map(messages, &Broadway.Message.failed(&1, reason))
    end
  end

  defp validate(%{"body" => body}) when is_binary(body) and body != "" do
    {:ok, %{"body" => String.slice(body, 0, 10_000), :processed_at => DateTime.utc_now()}}
  end

  defp validate(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> validate(parsed)
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp validate(_), do: {:error, :invalid_message}
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

## Testing

```elixir
defmodule MyApp.MessagePipelineTest do
  use ExUnit.Case
  import Broadway.Test

  test "processes a single message" do
    ref = push_message(MyApp.MessagePipeline, %{id: 1, value: "hello"})
    assert_receive {:ack, ^ref, [%{data: %{id: 1}}], []}
  end

  test "marks malformed messages as failed" do
    ref = push_message(MyApp.MessagePipeline, nil)
    assert_receive {:ack, ^ref, [], [_failed]}
  end
end
```

---

## Retry Strategies

- **Short-term retries**: wrap `process/1` in a retry library (e.g., `Retry`); failures bubble to `handle_failed/2`.
- **Long-term / exponential backoff**: send failed messages to a dead-letter queue and re-enqueue, or use producer-level redelivery.

```elixir
@impl true
def handle_message(_, message, _context) do
  attempt = Map.get(message.metadata, :retry_count, 0)

  case process(message.data) do
    {:ok, result} ->
      Broadway.Message.update_data(message, fn _ -> result end)

    {:error, reason} when attempt < 3 ->
      Broadway.Message.failed(message, {:retryable, reason})

    {:error, reason} ->
      Broadway.Message.failed(message, {:max_retries_exceeded, reason})
  end
end
```

---

## Producer Configurations

### SQS

```elixir
producer: [
  module: {BroadwaySQS.Producer,
    queue_url: System.get_env("SQS_QUEUE_URL"),
    config: [region: "us-west-2", max_number_of_messages: 10, wait_time_seconds: 20]},
  concurrency: 1
],
processors: [default: [concurrency: 10, max_demand: 10, min_demand: 5]],
batchers: [default: [concurrency: 5, batch_size: 100, batch_timeout: 5_000]]
```

### Kafka

```elixir
producer: [
  module: {BroadwayKafka.Producer,
    brokers: ["localhost:9092"],
    group_id: "my_consumer_group",
    topics: ["my-topic"]}
],
processors: [default: [concurrency: 10]],
batchers: [default: [concurrency: 5, batch_size: 100, batch_timeout: 5_000]]
```

---

## Telemetry

Attach handlers via `:telemetry.attach_many/4` in application startup:

```elixir
:telemetry.attach_many(
  "broadway-handler",
  [
    [:broadway, :message, :start],
    [:broadway, :message, :stop],
    [:broadway, :message, :failure],
    [:broadway, :batch, :start],
    [:broadway, :batch, :stop]
  ],
  &MyApp.Telemetry.handle_event/4,
  %{}
)
```

Optionally visualise metrics with [`broadway_dashboard`](https://hexdocs.pm/broadway_dashboard/). See the [Broadway Telemetry guide](https://hexdocs.pm/broadway/Broadway.html#module-telemetry) for full event names and metadata shapes.

---

## Concurrency Tuning

```elixir
processors: [
  default: [
    concurrency: System.schedulers_online() * 2,  # multiply by 4 for heavy I/O
    max_demand: 50                                 # raise to 100 for I/O-bound
  ]
]

batchers: [
  default: [
    concurrency: System.schedulers_online(),
    batch_size: 100,
    batch_timeout: 5_000
  ]
]
```
