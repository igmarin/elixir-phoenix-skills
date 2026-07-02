# Telemetry handler template — copy into lib/my_app/telemetry_handlers.ex and adapt.
# Attach handlers once when the app boots; detach them on shutdown so hot code
# reloads and test runs don't leave stale handlers registered.

defmodule MyApp.TelemetryHandlers do
  require Logger

  @handler_id "my-app-telemetry"

  @events [
    [:my_app, :orders, :created],
    [:my_app, :payments, :processed]
  ]

  # Called from MyApp.Application.start/2.
  def attach do
    :telemetry.attach_many(@handler_id, @events, &__MODULE__.handle_event/4, %{})
  end

  # Called from MyApp.Application.stop/1.
  def detach do
    :telemetry.detach(@handler_id)
  end

  def handle_event([:my_app, :orders, :created], measurements, metadata, _config) do
    Logger.info("Order created",
      count: measurements.count,
      total_cents: measurements.total_cents,
      user_id: metadata.user_id
    )
  end

  def handle_event([:my_app, :payments, :processed], measurements, metadata, _config) do
    Logger.info("Payment processed",
      amount_cents: measurements.amount_cents,
      user_id: metadata.user_id
    )
  end
end

defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    MyApp.TelemetryHandlers.attach()

    children = [MyApp.Repo, MyAppWeb.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end

  @impl true
  def stop(_state) do
    MyApp.TelemetryHandlers.detach()
    :ok
  end
end
