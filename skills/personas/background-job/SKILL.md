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
# Background Job Persona

Orchestrates robust background job implementation with TDD discipline, proper retry/discard strategies, comprehensive failure scenario testing, and production monitoring for Oban jobs.

---

## Phase 1: Job Design

**Objective:** Define job responsibilities, idempotency strategy, and error classification before writing code.

**Steps:**
1. **Job Purpose** — Define trigger conditions, input parameters, expected output/side effects, and criticality.
2. **Idempotency** — Design job to be safely re-runnable: use unique job keys, status checks, or sentinel timestamps.
3. **Error Classification** — Classify all anticipated errors:
   - Transient (network timeouts, rate limits, DB connection errors) → retry
   - Permanent (invalid data, record not found, validation failures) → discard
   - Configuration (missing credentials) → alert
4. **Queue & Timeout** — Assign queue priority and set execution timeout.

**HARD GATE — Job Design Complete:**
- [ ] Purpose, trigger, input/output defined
- [ ] Idempotency strategy specified
- [ ] All errors classified as transient/permanent
- [ ] Queue and timeout values chosen
- [ ] Unique job key or deduplication strategy

**If gate fails:** Clarify requirements before implementation.

---

## Phase 2: TDD Implementation

**Objective:** Implement job logic under TDD discipline.

**Steps:**
1. Choose unit test approach (test the `perform/1` function directly).
2. Write failing tests covering: successful execution, idempotency (run twice = same result), transient error raises, permanent error discards.
3. Confirm tests **FAIL** for the right reason (job not yet implemented).
4. Propose implementation approach and wait for explicit user approval.
5. Implement job using the structure shown in Phase 3; confirm tests **PASS**.
6. Run full test suite: `mix test` — confirm no regressions.

**HARD GATE — Tests Pass:**
- [ ] Tests exist and run
- [ ] Tests failed before implementation
- [ ] All tests pass after implementation
- [ ] Full suite green

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

**Objective:** Harden job for production with correct retry backoff, discard rules, timeouts, and monitoring hooks.

**Steps:**
1. Configure `max_attempts` for retry with exponential backoff.
2. Apply `discard_on` or explicit handling for permanent errors.
3. Set execution timeout at the job level.
4. Wire telemetry events for monitoring (see **infrastructure/telemetry-essentials**).

**Complete job implementation:**
```elixir
defmodule MyApp.Workers.SendWelcomeEmail do
  use Oban.Worker,
    queue: :mailers,
    max_attempts: 5,
    unique: [period: 300]

  alias MyApp.Accounts
  alias MyApp.Emails

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user!(user_id)

    # Idempotency guard
    if user.welcome_email_sent_at do
      Logger.info("Welcome email already sent to user #{user_id}")
      return :ok
    end

    case Emails.send_welcome(user) do
      :ok ->
        Accounts.mark_welcome_sent(user)
        Logger.info("Welcome email sent to user #{user_id}")
        :ok

      {:error, :rate_limited} ->
        Logger.warning("Rate limited sending welcome email to user #{user_id}")
        {:error, "Rate limited — will retry"}

      {:error, :invalid_email} ->
        Logger.error("Invalid email for user #{user_id} — discarding")
        Accounts.mark_welcome_failed(user, :invalid_email)
        :discard

      {:error, reason} ->
        Logger.error("Failed to send welcome email to user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
```

**Telemetry hook:**
```elixir
# In your Application module or a telemetry supervisor
:telemetry.attach(
  "oban-job-handler",
  [:oban, :job, :stop],
  fn _event, _measurements, metadata, _config ->
    duration = metadata.duration
    job_type = metadata.worker
    state = metadata.state

    # Emit to your metrics backend
    :telemetry.execute([:my_app, :oban, :job], %{duration: duration}, %{
      worker: job_type,
      state: state
    })
  end,
  nil
)
```

**HARD GATE — Retry Strategy Configured:**
- [ ] `max_attempts` set with appropriate backoff
- [ ] Permanent errors return `:discard` or `{:error, reason}` for retry
- [ ] Timeout configured at job level
- [ ] Telemetry/observability wired

**If gate fails:** Job is not production-ready.

---

## Phase 4: Failure Scenario Testing & Monitoring

**Objective:** Verify retry/discard behaviour under injected failures and confirm observability.

**Steps:**
1. Test that transient errors return `{:error, ...}` (Oban will retry).
2. Test that permanent errors return `:discard` (Oban will not retry).
3. Test idempotency: running the job twice produces no duplicate side effects.
4. Verify telemetry events fire on success and failure paths.
5. Confirm monitoring dashboard or alert is configured for queue depth.

**HARD GATE — Failure Scenarios Tested:**
- [ ] Transient error → returns `{:error, ...}` (Oban retries)
- [ ] Permanent error → returns `:discard` (not re-enqueued)
- [ ] Idempotency → no duplicate side effects
- [ ] Error logging assertions pass
- [ ] Performance acceptable under expected load

**If gate fails:** Address failure scenarios before deploying.

---

## HARD GATE: Production Readiness

**Never deploy a background job without:**
- Idempotency guard implemented and tested
- All transient errors return `{:error, reason}`
- All permanent errors return `:discard`
- `max_attempts` configured
- Failure scenario tests passing
- Telemetry and error-logging wired
- Queue timeout configured

## Error Recovery

**Job fails repeatedly in production:**
1. Check Oban dashboard for retry counts and error reasons.
2. Review logs for error class and stack trace.
3. Classify error (transient vs. permanent) and adjust handling.
4. Fix root cause; redeploy.

**Queue backs up:**
1. Scale Oban queue concurrency.
2. Promote critical jobs to a higher-priority queue.
3. Optimise job execution time or batch size.

## Output Style

When completing a background job implementation, output MUST include:

```markdown
# Background Job Report — [Job Name]

## Design
- Worker module: <path>
- Purpose: <one-line description>
- Idempotency strategy: <unique constraint / status check / conditional guard>
- Error classification: transient (<list>) / permanent (<list>)

## TDD
- Test: <test file path>
- RED: <failure message confirming job behavior missing>
- GREEN: <test passes after implementation>

## Retry Configuration
- max_attempts: <n>
- Queue: <queue name>
- Uniqueness: <period / fields>
- Discard conditions: <list>

## Failure Scenarios Tested
- Transient error → retries: ✓
- Permanent error → discards: ✓
- Idempotency → no duplicate side effects: ✓

## Monitoring
- Telemetry events: <list>
- Error logging: Logger.error configured
- Queue depth alerts: <configured threshold>
```

---

## Integration

| Predecessor | This Persona | Successor |
|-------------|--------------|----------|
| oban-essentials | background-job | quality |
| tdd | background-job | code-quality |
| None (standalone) | background-job | PR submission |

**Use `oban-essentials` alone** if the job design is already decided and you only need to implement the worker module.
