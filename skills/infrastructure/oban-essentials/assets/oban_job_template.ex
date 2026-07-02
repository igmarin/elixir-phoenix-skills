# Oban worker template — copy into lib/my_app/workers/ and adapt.
# Add {:oban, "~> 2.17"} to mix.exs and configure the queue in config/config.exs.

defmodule MyApp.Workers.SendWelcomeEmail do
  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    # Dedupe: no second job for the same user within a 5-minute window.
    unique: [period: 300, fields: [:args], keys: [:user_id]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case MyApp.Accounts.get_user(user_id) do
      nil ->
        # Permanent failure — do not retry.
        {:cancel, "user #{user_id} not found"}

      user ->
        # Idempotency guard: the same job may run more than once.
        if user.welcome_email_sent_at do
          {:ok, :already_sent}
        else
          deliver_and_mark(user)
        end
    end
  end

  defp deliver_and_mark(user) do
    with {:ok, _} <- MyApp.Mailer.send_welcome(user),
         {:ok, _} <- MyApp.Accounts.mark_welcome_sent(user) do
      {:ok, :sent}
    else
      # Retryable failure — Oban retries up to max_attempts.
      {:error, reason} -> {:error, reason}
    end
  end

  # Custom backoff: exponential with a small jitter, capped by max_attempts.
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(2, attempt)) + :rand.uniform(10)
  end
end
