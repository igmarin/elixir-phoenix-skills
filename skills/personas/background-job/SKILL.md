---
name: background-job
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates robust Oban background job implementation with hard gates: design job with idempotency strategy and error classification (transient→retry, permanent→discard) → TDD implementation where test MUST fail before code → configure retry/discard strategies → test failure scenarios covering idempotency/retry/error handling → production monitoring; phases design→TDD→retry config→failure testing→monitoring. Use when adding async processing, implementing background jobs, or configuring job queues. Trigger: background job, async processing, oban, job queue, worker.

## Phase 1: Job Design

**Steps:**
1. **Job Purpose** — Define trigger conditions, input parameters, expected output/side effects, and criticality.
2. **Idempotency** — Design job to be safely re-runnable: use unique job keys, status checks, or sentinel timestamps.
3. **Error Classification** — Classify all anticipated errors:
   - Transient (network timeouts, rate limits, DB connection errors) → return `{:error, reason}`
   - Permanent (invalid data, record not found, validation failures) → return `:discard`
   - Configuration (missing credentials) → alert
4. **Queue & Timeout** — Assign queue priority and set execution timeout.

**HARD GATE — Job Design Complete:**
- [ ] Idempotency strategy is documented with a specific mechanism (unique key / status check / sentinel timestamp)
- [ ] Every anticipated error is assigned to exactly one category (transient or permanent) with rationale
- [ ] Queue name, priority, and timeout value are recorded and justified

---

## Phase 2: TDD Implementation

**Steps:**
1. Write failing tests covering: successful execution, idempotency (run twice = same result), transient error raises, permanent error discards.
2. Confirm tests **FAIL** for the right reason (job not yet implemented).
3. Propose implementation approach and wait for explicit user approval.
4. Implement job; confirm tests **PASS**.
5. Run full test suite: `mix test` — confirm no regressions.

**HARD GATE — Tests Pass:**
- [ ] RED confirmed: test output shows failures attributable to missing implementation, not misconfiguration
- [ ] GREEN confirmed: all tests pass including idempotency scenario; `mix test` exits clean with no regressions

**Example job test skeleton** (for `SendWelcomeEmail` worker):
```elixir
# test/my_app/workers/send_welcome_email_test.exs
defmodule MyApp.Workers.SendWelcomeEmailTest do
  use MyApp.DataCase, async: true

  alias MyApp.Workers.SendWelcomeEmail

  setup do
    user = user_fixture()
    %{user: user}
  end

  test "sends welcome email", %{user: user} do
    assert :ok = SendWelcomeEmail.perform(%Oban.Job{args: %{"user_id" => user.id}})
  end

  test "is idempotent", %{user: user} do
    job = %Oban.Job{args: %{"user_id" => user.id}}
    assert :ok = SendWelcomeEmail.perform(job)
    assert :ok = SendWelcomeEmail.perform(job)
  end

  test "raises on transient email errors" do
    job = %Oban.Job{args: %{"user_id" => -1}}
    assert {:error, _} = SendWelcomeEmail.perform(job)
  end
end
```

---

## Phase 3: Retry/Discard Configuration

**Steps:**
1. Configure `max_attempts` for retry with exponential backoff.
2. Apply `discard_on` or explicit handling for permanent errors (per the error classification in Phase 1).
3. Set execution timeout at the job level.
4. Wire telemetry events for monitoring (see `telemetry-essentials` for patterns).

**Key implementation pattern:**
```elixir
defmodule MyApp.Workers.SendWelcomeEmail do
  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [period: 300]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user!(user_id)

    # Idempotency guard
    if user.welcome_email_sent_at, do: return(:ok)

    case Emails.send_welcome(user) do
      :ok              -> Accounts.mark_welcome_sent(user); :ok
      {:error, :rate_limited}  -> {:error, "Rate limited — will retry"}
      {:error, :invalid_email} -> Accounts.mark_welcome_failed(user, :invalid_email); :discard
      {:error, reason}         -> {:error, reason}
    end
  end
end
```

**HARD GATE — Retry Strategy Configured:**
- [ ] `max_attempts`, backoff, and timeout are set to values derived from the Phase 1 error classification
- [ ] Every permanent error maps to `:discard` in code; every transient error maps to `{:error, reason}`
- [ ] Telemetry events are attached and verifiable in tests

---

## Phase 4: Failure Scenario Testing & Monitoring

**Steps:**
1. For each error classified in Phase 1, assert the correct return value (transient → `{:error, ...}`, permanent → `:discard`).
2. Verify telemetry events fire on success and failure paths.
3. Confirm monitoring dashboard or alert is configured for queue depth (see `telemetry-essentials` for alerting patterns).

**HARD GATE — Failure Scenarios Tested:**
- [ ] Every error path from Phase 1 has a corresponding test assertion with the correct return value
- [ ] Telemetry/logging assertions pass for both success and failure paths
- [ ] Queue depth alert threshold is set and its value is documented

**Never deploy until all four phase gates above are green.**

---

## Output Style

When completing a background job implementation, produce a concise summary report:

```
# Background Job Report — [Job Name]
- Worker module: <path>
- Idempotency strategy: <unique constraint / status check / conditional guard>
- Error classification: transient (<list>) / permanent (<list>)
- RED: <failure message confirming job behavior missing>
- GREEN: <test passes after implementation>
- max_attempts: <n>, Queue: <name>, Uniqueness: <period/fields>
- Discard conditions: <list>
- Telemetry events: <list>
- Queue depth alerts: <configured threshold>
```
