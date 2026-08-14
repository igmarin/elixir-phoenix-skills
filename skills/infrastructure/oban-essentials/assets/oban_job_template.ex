# FCIS: perform/1 is an edge — fetch by id, call context/pure modules, return tuples.
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
    with {:ok, user} <- MyApp.Accounts.fetch_user(user_id),
         {:ok, result} <- MyApp.Accounts.send_welcome_if_needed(user) do
      {:ok, result}
    else
      {:error, :not_found} -> {:cancel, "user #{user_id} not found"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Custom backoff: exponential with a small jitter, capped by max_attempts.
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    trunc(:math.pow(2, attempt)) + :rand.uniform(10)
  end
end
