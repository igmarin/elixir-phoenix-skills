---
name: background-job
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates robust Oban background job implementation with hard gates: design job with idempotency strategy and error classification (transient→retry, permanent→discard) → TDD implementation where test MUST fail before code → configure retry/discard strategies → test failure scenarios covering idempotency/retry/error handling → production monitoring; phases design→TDD→retry config→failure testing→monitoring. Use when adding async processing, implementing background jobs, or configuring job queues. Trigger: background job, async processing, oban, job queue, worker.
---

## Agent Phases

### Phase 1: Job Design

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

**If gate fails:** Return to job design — document the missing idempotency mechanism, complete the error classification, or record the queue/priority/timeout value before writing any code.


### Phase 2: TDD Implementation

**Steps:**
1. Write failing tests covering: successful execution, idempotency (run twice = same result), transient error raises, permanent error discards.
2. Confirm tests **FAIL** for the right reason (job not yet implemented).
3. Propose implementation approach and wait for explicit user approval.
4. Implement job; confirm tests **PASS**.
5. Run full test suite: `mix test` — confirm no regressions.

**HARD GATE — Tests Pass:**
- [ ] RED confirmed: test output shows failures attributable to missing implementation, not misconfiguration
- [ ] GREEN confirmed: all tests pass including idempotency scenario; `mix test` exits clean with no regressions

**If gate fails:** If RED is wrong (misconfiguration or syntax, not a missing implementation), fix the test first; if GREEN fails, revise the implementation and do not proceed until `mix test` passes with no regressions.

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


### Phase 3: Retry/Discard Configuration

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

**If gate fails:** Re-derive `max_attempts`, backoff, and timeout from the Phase 1 error classification, and correct any error whose return value contradicts its class (`{:error, reason}` for transient, `:discard` for permanent).


### Phase 4: Failure Scenario Testing & Monitoring

**Steps:**
1. For each error classified in Phase 1, assert the correct return value (transient → `{:error, ...}`, permanent → `:discard`).
2. Verify telemetry events fire on success and failure paths.
3. Confirm monitoring dashboard or alert is configured for queue depth (see `telemetry-essentials` for alerting patterns).

**HARD GATE — Failure Scenarios Tested:**
- [ ] Every error path from Phase 1 has a corresponding test assertion with the correct return value
- [ ] Telemetry/logging assertions pass for both success and failure paths
- [ ] Queue depth alert threshold is set and its value is documented

**If gate fails:** Add the missing error-path assertion or telemetry check, or set and document the queue-depth threshold, then re-run the failure-scenario tests.

**Never deploy until all four phase gates above are green.**


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

## Error Recovery

**Effects duplicate when a job retries:**
1. Confirm the Phase 1 idempotency guard actually short-circuits (unique key, status check, or sentinel timestamp).
2. Add a test that calls `perform/1` twice and asserts a single side effect.

**A transient error is discarded (or a permanent error keeps retrying):**
1. Recheck the offending error against the Phase 1 classification.
2. Map transient errors to `{:error, reason}` (retryable) and permanent errors to `:discard`, and adjust `max_attempts` to match.

**A job exhausts its retries in production:**
1. Inspect the Oban dashboard for the failure reason and attempt count.
2. If the error is actually permanent, add a `:discard` branch; if transient and recoverable, raise `max_attempts` or widen the backoff.

**The queue backs up (depth alert firing):**
1. Look for a poison job blocking the queue or under-provisioned queue concurrency.
2. Increase concurrency or move the slow job to a dedicated queue, then confirm the depth alert clears.
