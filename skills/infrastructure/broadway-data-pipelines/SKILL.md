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
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Broadway Data Pipelines

## RULES — Follow these with no exceptions

1. **Use `Broadway.Message.failed/2` for errors** — never raise in `handle_message/3`
2. **Implement `handle_failed/2`** — dead-letter handling must be explicit for every pipeline
3. **Use batchers for database inserts** — don't insert one-by-one; batch size of 100 is a good default
4. **Configure `:status` in start_link** — set `:max_restarts`, `:max_seconds` for production resilience
5. **Test with `Broadway.Test.push_message/2`** — verify each message type including failures
6. **Wire telemetry** — attach handlers to Broadway's telemetry events for observability

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

See [`assets/broadway_pipeline_template.ex`](assets/broadway_pipeline_template.ex) for a copy-paste Broadway module skeleton (`start_link/1`, producer config, `handle_message/3`, `handle_batch/4`, `handle_failed/2`).

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
    case process(message.data) do
      {:ok, result} ->
        message
        |> Broadway.Message.update_data(fn _ -> result end)
        |> Broadway.Message.put_batcher(:default)

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
    data = Enum.map(messages, & &1.data)
    case MyApp.Repo.insert_all(MyApp.Record, data) do
      {_count, _} ->
        messages

      {:error, reason} ->
        Logger.error("Batch failed: #{inspect(reason)}")
        Enum.map(messages, &Broadway.Message.failed(&1, reason))
    end
  end

  defp process(%{"body" => body} = data) do
    sanitized = %{data | "body" => String.slice(body || "", 0, 10_000)}
    {:ok, Map.put(sanitized, :processed_at, DateTime.utc_now())}
  end
  defp process(data) when is_map(data) do
    {:ok, Map.put(data, :processed_at, DateTime.utc_now())}
  end
  defp process(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> process(parsed)
      {:error, _} -> {:error, :invalid_json}
    end
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

Broadway has no built-in backoff/requeue at the message level:

- **Short-term retries**: wrap `process/1` in a retry library (e.g., `Retry`); unrecoverable failures surface in `handle_failed/2`.
- **Long-term / exponential backoff**: send failed messages to a dead-letter queue and re-enqueue from there, or rely on producer-level redelivery (SQS visibility timeout, Kafka consumer group offset management).
- **Retry count tracking**: must be implemented in your own producer or via the external queue's message attributes — Broadway does not populate retry metadata automatically.

Because Broadway has no message-level retry, `handle_failed/2` is where you inspect each
failed message's `status`/`metadata` and decide whether to dead-letter it or re-enqueue it
with a bumped retry counter:

```elixir
@impl true
def handle_failed(messages, _context) do
  Enum.map(messages, fn message ->
    retries = message.metadata[:retry_count] || 0

    case message.status do
      # Non-retryable: route straight to the dead-letter queue
      {:failed, :invalid_json} ->
        DeadLetterQueue.send(message.data, :invalid_json)
        message

      # Retryable and under the cap: re-enqueue via the external queue with a higher count
      {:failed, _reason} when retries < 3 ->
        MyApp.Requeue.push(message.data, retry_count: retries + 1)
        message

      # Retries exhausted: dead-letter it so the pipeline keeps draining
      {:failed, reason} ->
        Logger.error("Dropping message after #{retries} retries: #{inspect(reason)}")
        DeadLetterQueue.send(message.data, reason)
        message
    end
  end)
end
```

---

## Producer Configurations

### SQS

```elixir
Broadway.start_link(__MODULE__,
  name: __MODULE__,
  producer: [
    module: {
      BroadwaySQS.Producer,
      queue_url: System.get_env("SQS_QUEUE_URL"),
      config: [
        region: "us-west-2",
        max_number_of_messages: 10,
        wait_time_seconds: 20
      ]
    },
    concurrency: 1
  ],
  processors: [
    default: [concurrency: 10, max_demand: 10, min_demand: 5]
  ],
  batchers: [
    default: [concurrency: 5, batch_size: 100, batch_timeout: 5_000]
  ]
)
```

### Kafka

```elixir
Broadway.start_link(__MODULE__,
  name: __MODULE__,
  producer: [
    module: {
      BroadwayKafka.Producer,
      brokers: ["localhost:9092"],
      group_id: "my_consumer_group",
      topics: ["my-topic"]
    }
  ],
  processors: [
    default: [concurrency: 10]
  ],
  batchers: [
    default: [concurrency: 5, batch_size: 100, batch_timeout: 5_000]
  ]
)
```

---

## Telemetry

Broadway emits telemetry events for message processing and batching. Attach handlers via `:telemetry.attach_many/4` in your application startup:

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
    concurrency: System.schedulers_online() * 2,
    max_demand: 50
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

- **CPU-bound**: fewer workers, lower demand
- **I/O-bound**: more workers (`* 4`), higher `max_demand` (100)

---

## Common Pitfalls

| ❌ Don't | ✅ Do |
|----------|-------|
| Raise inside `handle_message/3` on a bad message | Return `Broadway.Message.failed(message, reason)` so the pipeline keeps draining |
| Skip `handle_failed/2` and lose failed messages | Implement `handle_failed/2` to dead-letter or re-enqueue every failure |
| Insert records one-by-one in `handle_message/3` | Batch DB writes in `handle_batch/4` (batch size ~100) |
| Expect Broadway to retry with backoff automatically | Track retries yourself (message metadata / external queue redelivery) |
| Hardcode processor/batcher concurrency to a fixed number | Tune from `System.schedulers_online()` for the workload profile |
| Ship without observability | Attach handlers to Broadway telemetry events before scaling up |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| otp-essentials | broadway-data-pipelines | telemetry-essentials |
| ecto-essentials | broadway-data-pipelines | deployment-gotchas |

**Companion skills:**
- `oban-essentials` — in-app background jobs when you don't need an external message queue
- `telemetry-essentials` — attach handlers to Broadway's telemetry events
- `deployment-gotchas` — configure producers and supervision for production releases
