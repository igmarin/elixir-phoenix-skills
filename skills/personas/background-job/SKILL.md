---
name: background-job
type: persona
tags: [personas]
license: MIT
description: >
  Orchestrates robust Oban background job implementation with hard gates: design job with idempotency strategy and error classification (transient→retry, permanent→discard) → TDD implementation where test MUST fail before code → configure retry/discard strategies → test failure scenarios covering idempotency/retry/error handling → production monitoring; phases design→TDD→retry config→failure testing→monitoring. Use when adding async processing, implementing background jobs, or configuring job queues. Trigger: background job, async processing, oban, job queue, worker.
metadata:
  version: 1.0.0
  user-invocable: "true"
  entry_point: "Invoke when implementing background jobs with proper retry/discard strategies and monitoring"
  phases: "Phase 1: Job Design, Phase 2: TDD Implementation, Phase 3: Retry/Discard Configuration, Phase 4: Testing & Monitoring"
  hard_gates: "Job Design Complete, Tests Pass, Retry Strategy Configured, Failure Scenarios Tested"
  dependencies:
    - source: self
      skills: [oban-essentials, testing-essentials, telemetry-essentials]
  keywords: elixir, oban, background-job, async, retry, monitoring, worker
---

Orchestrates robust background job implementation with TDD discipline, proper retry/discard strategies, comprehensive failure scenario testing, and production monitoring for Oban jobs.

---

## Phase 1: Job Design

**Steps:**
1. **Job Purpose** — Define trigger conditions, input parameters, expected output/side effects, and criticality.
2. **Idempotency** — Design job to be safely re-runnable: use unique job keys, status checks, or sentinel timestamps.
3. **Error Classification** — Classify all anticipated errors (this classification governs Phases 3 and 4):
   - Transient (network timeouts, rate limits, DB connection errors) → return `{:error, reason}`
   - Permanent (invalid data, record not found, validation failures) → return `:discard`
   - Configuration (missing credentials) → alert
4. **Queue & Timeout** — Assign queue priority and set execution timeout.

**HARD GATE — Job Design Complete:**
- [ ] Purpose, trigger, input/output defined
- [ ] Idempotency strategy specified
- [ ] All errors classified as transient/permanent
- [ ] Queue and timeout values chosen

**If gate fails:** Clarify requirements and finish the design before writing any implementation.

---

## Phase 2: TDD Implementation

**Steps:**
1. Choose unit test approach (test the `perform/1` function directly).
2. Write failing tests covering: successful execution, idempotency (run twice = same result), transient error raises, permanent error discards.
3. Confirm tests **FAIL** for the right reason (job not yet implemented).
4. Propose implementation approach and wait for explicit user approval.
5. Implement job; confirm tests **PASS**.
6. Run full test suite: `mix test` — confirm no regressions.

**HARD GATE — Tests Pass:**
- [ ] RED confirmed (tests failed before implementation)
- [ ] GREEN confirmed (all tests pass, including idempotency scenario)
- [ ] Full suite green

**If gate fails:** Tests are not trustworthy — do not configure retries until RED→GREEN is proven.

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
2. Return `{:error, reason}` for transient errors and `:discard` for permanent errors (per the classification in Phase 1).
3. Set execution timeout at the job level.
4. Wire telemetry events for monitoring.

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
- [ ] `max_attempts` set with appropriate backoff
- [ ] Permanent errors return `:discard`; transient errors return `{:error, reason}`
- [ ] Timeout and telemetry/observability configured

**If gate fails:** Job is not production-ready — do not proceed to failure testing.

---

## Phase 4: Failure Scenario Testing & Monitoring

Assert the correct return value for every error path classified in Phase 1:

**Steps:**
1. For each transient error → assert `{:error, ...}`
2. For each permanent error → assert `:discard`
3. Verify telemetry events fire on success and failure paths.
4. Confirm monitoring dashboard or alert is configured for queue depth.

**HARD GATE — Failure Scenarios Tested:**
- [ ] All transient error paths verified → `{:error, ...}`
- [ ] All permanent error paths verified → `:discard`
- [ ] Telemetry/logging assertions pass
- [ ] Performance acceptable under expected load

**If gate fails:** Address the failing failure-scenario paths before deploying.

**Never deploy until all four phase gates above are green.**

---

## Output Style

When completing a background job implementation, output MUST follow this structure:

```
# Background Job Report — [Job Name]
## Design
- Worker module: <path>
- Idempotency strategy: <unique constraint / status check / conditional guard>
- Error classification: transient (<list>) / permanent (<list>)
## TDD
- RED: <failure message confirming job behavior missing>
- GREEN: <test passes after implementation>
## Retry Configuration
- max_attempts: <n>, Queue: <name>, Uniqueness: <period/fields>
- Discard conditions: <list>
## Failure Scenarios Tested
- Transient error → retries: ✓
- Permanent error → discards: ✓
- Idempotency → no duplicate side effects: ✓
## Monitoring
- Telemetry events: <list>
- Queue depth alerts: <configured threshold>
```

---

## Error Recovery

**Tests won't go RED:** The behavior may already exist or the test asserts the wrong thing. Rewrite the test to fail for the intended reason before implementing.

**Job retries forever / never discards:** A permanent error is being returned as `{:error, reason}`. Reclassify it (Phase 1) and return `:discard` so Oban stops retrying.

**Duplicate side effects on retry:** Idempotency guard is missing or races. Add a unique constraint (`unique: [period: ...]`) or a status/sentinel check at the top of `perform/1`.

**Job silently vanishes:** It returned `:discard` (or raised) on what was actually a transient error. Move that branch back to `{:error, reason}` and confirm `max_attempts` is set.

**Queue backs up in production:** Increase queue concurrency or shard the queue; verify telemetry/queue-depth alerts fire, then rerun Phase 4 load checks.
