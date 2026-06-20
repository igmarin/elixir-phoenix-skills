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

## Minimal Pipeline

A simple starting point. Handles a message and inserts a batch into the database.

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

## Production-Ready Pipeline

Expands the minimal example with structured error handling, a dead-letter queue, and batch failure recovery. Use this variant when reliability and observability matter.

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

> **Telemetry:** Broadway emits telemetry events for message processing and batching. Attach handlers via `:telemetry.attach_many/4` to handle multiple event patterns with a single callback, and optionally visualise them with [`broadway_dashboard`](https://hexdocs.pm/broadway_dashboard/). See the [Broadway Telemetry guide](https://hexdocs.pm/broadway/Broadway.html#module-telemetry) for event names and metadata.

```elixir
:telemetry.attach_many(
  "broadway-handler",
  [
    [:broadway, :message, :start],
    [:broadway, :message, :stop],
    [:broadway, :message, :failure]
  ],
  &MyApp.Telemetry.handle_event/4,
  %{}
)
```

---

## SQS Producer Configuration

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
    default: [
      concurrency: 10,
      max_demand: 10,
      min_demand: 5
    ]
  ],
  batchers: [
    default: [
      concurrency: 5,
      batch_size: 100,
      batch_timeout: 5_000
    ]
  ]
)
```

---

## Kafka Producer Configuration

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

## Message Transformation

```elixir
@impl true
def handle_message(_, message, _context) do
  message
  |> Broadway.Message.update_data(&parse_json/1)
  |> Broadway.Message.put_batcher(:default)
rescue
  e ->
    Broadway.Message.failed(message, :invalid_json)
end

defp parse_json(%{} = data), do: data
defp parse_json(data) when is_binary(data) do
  case Jason.decode(data) do
    {:ok, parsed} -> parsed
    {:error, _} -> raise "Invalid JSON"
  end
end
```

---

## Rate Limiting

```elixir
defmodule MyApp.RateLimitedPipeline do
  use Broadway

  # Limit to 1000 messages per second
  @rate_limit 1000

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwaySQS.Producer, queue_url: System.get_env("SQS_QUEUE_URL")}
      ],
      processors: [
        default: [
          concurrency: 10,
          max_demand: 10
        ]
      ],
      batchers: [
        default: [concurrency: 5, batch_size: 100, batch_timeout: 2000]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _context) do
    # Apply rate limiting
    Process.sleep(1000 / @rate_limit)

    message
    |> Broadway.Message.update_data(&process_data/1)
    |> Broadway.Message.put_batcher(:default)
  end

  defp process_data(data), do: data
end
```

---

## Retry Strategies

```elixir
@impl true
def handle_message(_, message, _context) do
  attempt = Map.get(message.data, :retry_count, 0)

  case process_with_retry(message.data, attempt) do
    {:ok, result} ->
      Broadway.Message.update_data(message, fn _ -> result end)

    {:error, reason} when attempt < 3 ->
      # Requeue with incremented retry count
      Broadway.Message.update_data(message, fn data ->
        Map.put(data, :retry_count, attempt + 1)
      end)
      |> Broadway.Message.put_backoff(attempt * 1000)

    {:error, reason} ->
      Broadway.Message.failed(message, {:max_retries_exceeded, reason})
  end
end

defp process_with_retry(data, attempt) do
  # Your processing logic here
  {:ok, data}
rescue
  e ->
    {:error, e}
end
```

---

## Telemetry Events

```elixir
# Attach telemetry handler in your application startup
:telemetry.attach(
  "broadway-handler",
  [:broadway, :message, :start],
  [:broadway, :message, :stop],
  [:broadway, :message, :failure],
  fn event, measurements, metadata, _ ->
    IO.puts("Event: #{event}")
    IO.puts("Measurements: #{inspect(measurements)}")
    IO.puts("Metadata: #{inspect(metadata)}")
  end
)
```

**Key telemetry events:**
- `[:broadway, :processor, :start]` — processor started
- `[:broadway, :processor, :stop]` — processor stopped
- `[:broadway, :batch, :start]` — batch processing started
- `[:broadway, :batch, :stop]` — batch processing completed
- `[:broadway, :message, :failure]` — message processing failed

---

## Concurrency Tuning

```elixir
# For CPU-bound processing
processors: [
  default: [
    concurrency: System.schedulers_online() * 2,
    max_demand: 50
  ]
]

# For I/O-bound processing
processors: [
  default: [
    concurrency: System.schedulers_online() * 4,
    max_demand: 100
  ]
]

# For mixed workloads
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
