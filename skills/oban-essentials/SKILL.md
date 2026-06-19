---
name: oban-essentials
type: atomic
license: MIT
description: >
  MANDATORY for ALL Oban work. Invoke before writing workers or enqueuing jobs.
  Covers worker definition, enqueuing, return values, queue configuration, idempotency,
  unique jobs, scheduled/recurring jobs, pruning, testing with Oban.Testing, and arg best practices.
  Trigger words: Oban, worker, job, queue, enqueue, perform, cron, idempotent, background job.
metadata:
  version: 1.0.0
  adapted-from: j-morgan6/elixir-phoenix-guide
  original-author: Joseph Morgan
---

# Oban Essentials

<!-- Adapted from j-morgan6/elixir-phoenix-guide (MIT License, Copyright (c) 2026 Joseph Morgan) -->

Use this skill before writing ANY Oban worker or enqueuing jobs.

## RULES — Follow these with no exceptions

1. **Always `use Oban.Worker`** with explicit `queue` and `max_attempts` options
2. **Return `{:ok, result}` for success, `{:error, reason}` for retryable failures, `{:cancel, reason}` for permanent failures** — never return bare `:ok` or raise
3. **Make workers idempotent** — the same job may run more than once due to retries or node restarts
4. **Use `unique` option to prevent duplicate jobs** — specify `period`, `fields`, and `keys`
5. **Test with `Oban.Testing`** — use `assert_enqueued` and `perform_job`, never call `perform/1` directly
6. **Never put large data in job args** — store IDs and fetch fresh data in the worker
7. **Use `Oban.insert/1`** (not `Oban.insert!/1`) and handle the error tuple
8. **Enqueue from contexts, not LiveViews** — keep web layer thin

---

## Worker Definition

```elixir
defmodule MyApp.Workers.SendWelcomeEmail do
  use Oban.Worker,
    queue: :mailers,
    max_attempts: 3,
    unique: [period: 300, fields: [:args], keys: [:user_id]]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case MyApp.Accounts.get_user(user_id) do
      nil ->
        {:cancel, "user #{user_id} not found"}

      user ->
        MyApp.Mailer.send_welcome(user)
        {:ok, :sent}
    end
  end
end
```

### Key Points

- `queue` — which queue runs this worker (must match config)
- `max_attempts` — total attempts including the first (3 = 1 original + 2 retries)
- `unique` — deduplication; `period` in seconds, `keys` specifies which args fields to compare
- Pattern match on `%Oban.Job{args: ...}` — args are always string-keyed maps (JSON serialized)

---

## Enqueuing Jobs

```elixir
# Basic insert — always handle the result
case MyApp.Workers.SendWelcomeEmail.new(%{user_id: user.id}) |> Oban.insert() do
  {:ok, job} -> {:ok, job}
  {:error, changeset} -> {:error, changeset}
end

# Schedule for later
%{user_id: user.id}
|> MyApp.Workers.SendWelcomeEmail.new(schedule_in: 3600)
|> Oban.insert()
```

❌ **Bad — raises on failure:**
```elixir
MyApp.Workers.SendWelcomeEmail.new(%{user_id: user.id}) |> Oban.insert!()
```

### Enqueuing from Contexts

✅ **Good — context handles the job:**
```elixir
defmodule MyApp.Accounts do
  def register_user(attrs) do
    with {:ok, user} <- create_user(attrs) do
      MyApp.Workers.SendWelcomeEmail.new(%{user_id: user.id})
      |> Oban.insert()

      {:ok, user}
    end
  end
end
```

❌ **Bad — LiveView enqueues directly:**
```elixir
def handle_event("register", params, socket) do
  MyApp.Workers.SendWelcomeEmail.new(%{user_id: user.id}) |> Oban.insert()
end
```

---

## Return Values

```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  # Success — job completed, marked as completed
  {:ok, result}

  # Retryable failure — will retry up to max_attempts
  {:error, reason}

  # Permanent failure — will NOT retry, marked as cancelled
  {:cancel, reason}

  # Snooze — reschedule for later (in seconds)
  {:snooze, 60}
end
```

**Never raise in workers.** An unhandled exception counts as a retryable failure but produces noisy logs and stack traces. Use explicit `{:error, reason}` instead.

---

## Queue Configuration

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [
    default: 10,      # 10 concurrent jobs
    mailers: 5,       # 5 concurrent email jobs
    imports: 2         # 2 concurrent import jobs (resource-heavy)
  ]

# config/test.exs — use testing mode
config :my_app, Oban,
  testing: :inline    # Jobs execute immediately in the test process
```

---

## Idempotency

Workers must be safe to run multiple times with the same args.

❌ **Bad — sends duplicate emails on retry:**
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
  user = MyApp.Accounts.get_user!(user_id)
  MyApp.Mailer.send_welcome(user)
  {:ok, :sent}
end
```

✅ **Good — check if already processed:**
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
  user = MyApp.Accounts.get_user!(user_id)

  if user.welcome_email_sent_at do
    {:ok, :already_sent}
  else
    with {:ok, _} <- MyApp.Mailer.send_welcome(user),
         {:ok, _} <- MyApp.Accounts.mark_welcome_sent(user) do
      {:ok, :sent}
    end
  end
end
```

---

## Unique Jobs

```elixir
use Oban.Worker,
  queue: :default,
  unique: [
    period: 300,              # 5-minute uniqueness window
    fields: [:args, :queue],  # match on these fields
    keys: [:user_id],         # only compare these arg keys
    states: [:available, :scheduled, :executing]
  ]
```

### When to Use

- **Email sending** — don't send the same email twice within 5 minutes
- **Data syncing** — don't start a sync if one is already running
- **Webhook delivery** — deduplicate retry attempts

---

## Scheduled and Recurring Jobs

```elixir
# Schedule a job for later
%{report_id: report.id}
|> MyApp.Workers.GenerateReport.new(schedule_in: {1, :hour})
|> Oban.insert()

# Cron-based recurring jobs (in config)
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [default: 10],
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"0 2 * * *", MyApp.Workers.NightlyCleanup},
      {"*/15 * * * *", MyApp.Workers.SyncData, args: %{source: "api"}}
    ]}
  ]
```

---

## Testing

```elixir
defmodule MyApp.Workers.SendWelcomeEmailTest do
  use MyApp.DataCase, async: true
  use Oban.Testing, repo: MyApp.Repo

  alias MyApp.Workers.SendWelcomeEmail

  test "enqueuing a welcome email job" do
    user = user_fixture()

    SendWelcomeEmail.new(%{user_id: user.id})
    |> Oban.insert()

    assert_enqueued(worker: SendWelcomeEmail, args: %{user_id: user.id})
  end

  test "performing the job sends the email" do
    user = user_fixture()

    assert {:ok, :sent} =
      perform_job(SendWelcomeEmail, %{user_id: user.id})
  end

  test "cancels if user not found" do
    assert {:cancel, _reason} =
      perform_job(SendWelcomeEmail, %{user_id: -1})
  end
end
```

### Testing Rules

- **Use `perform_job/2`** — not `perform/1`. `perform_job` validates args and simulates the Oban runtime.
- **Use `assert_enqueued/1`** — verify jobs were enqueued with correct args.
- **Use `Oban.Testing` inline mode** in test config — jobs run synchronously in the test process.
- **Test all return paths** — success, retryable error, and cancel.

---

## Job Args Best Practices

❌ **Bad — large data in args (stored as JSON in database):**
```elixir
SendReport.new(%{
  user_id: user.id,
  report_data: large_data_structure  # Don't do this!
})
```

✅ **Good — store IDs, fetch fresh data in worker:**
```elixir
SendReport.new(%{user_id: user.id, report_id: report.id})
```

---

## Common Pitfalls

❌ **Don't** raise in workers — use `{:error, reason}` or `{:cancel, reason}`
❌ **Don't** put large data in job args — store IDs and fetch in the worker
❌ **Don't** use `Oban.insert!/1` — handle the error tuple
❌ **Don't** enqueue from LiveViews — enqueue from contexts
❌ **Don't** forget to make workers idempotent
❌ **Don't** call `perform/1` directly in tests — use `perform_job/2`

✅ **Do** return tagged tuples for all outcomes
✅ **Do** use `unique` to prevent duplicate jobs
✅ **Do** test all return paths (success, error, cancel)
✅ **Do** configure queue concurrency based on resource needs
✅ **Do** use `Oban.Plugins.Pruner` to keep the jobs table clean

## Integration

| Skill | When to chain |
|-------|---------------|
| **testing-essentials** | Before writing worker tests |
| **elixir-essentials** | Before writing worker modules |
| **otp-essentials** | When choosing between Oban and raw OTP for background work |
| **broadway-data-pipelines** | When needing data pipeline processing instead of job queues |
