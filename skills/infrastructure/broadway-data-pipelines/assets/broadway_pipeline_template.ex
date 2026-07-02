# Broadway pipeline template — copy into lib/my_app/message_pipeline.ex and adapt.
# Add {:broadway, "~> 1.0"} (plus a producer library) to mix.exs, then add this
# module to your application's supervision tree.

defmodule MyApp.MessagePipeline do
  use Broadway

  require Logger

  @dead_letter_max_retries 3

  # start_link/1 wires the producer, processors, and batchers.
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwaySQS.Producer, queue_url: System.get_env("SQS_QUEUE_URL")},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: System.schedulers_online() * 2, max_demand: 10]
      ],
      batchers: [
        default: [concurrency: System.schedulers_online(), batch_size: 100, batch_timeout: 2_000]
      ]
    )
  end

  # handle_message/3 transforms each message and routes it to a batcher.
  # Never raise here — mark bad messages as failed instead.
  @impl true
  def handle_message(_processor, message, _context) do
    case decode_and_process(message.data) do
      {:ok, result} ->
        message
        |> Broadway.Message.update_data(fn _ -> result end)
        |> Broadway.Message.put_batcher(:default)

      {:error, reason} ->
        Broadway.Message.failed(message, reason)
    end
  end

  # handle_batch/4 performs bulk side effects (one DB round-trip per batch).
  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    rows = Enum.map(messages, & &1.data)

    case MyApp.Repo.insert_all(MyApp.Record, rows) do
      {_count, _} ->
        messages

      {:error, reason} ->
        Logger.error("Batch insert failed: #{inspect(reason)}")
        Enum.map(messages, &Broadway.Message.failed(&1, reason))
    end
  end

  # handle_failed/2 is the dead-letter / retry hook. Inspect status + metadata.
  @impl true
  def handle_failed(messages, _context) do
    Enum.map(messages, fn message ->
      retries = message.metadata[:retry_count] || 0

      case message.status do
        {:failed, :invalid_json} ->
          MyApp.DeadLetterQueue.send(message.data, :invalid_json)
          message

        {:failed, _reason} when retries < @dead_letter_max_retries ->
          MyApp.Requeue.push(message.data, retry_count: retries + 1)
          message

        {:failed, reason} ->
          Logger.error("Dropping message after #{retries} retries: #{inspect(reason)}")
          MyApp.DeadLetterQueue.send(message.data, reason)
          message
      end
    end)
  end

  defp decode_and_process(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, parsed} -> {:ok, Map.put(parsed, :processed_at, DateTime.utc_now())}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp decode_and_process(data) when is_map(data) do
    {:ok, Map.put(data, :processed_at, DateTime.utc_now())}
  end
end
