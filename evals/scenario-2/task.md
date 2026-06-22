# SaaS Subscriptions Context

## Background

You are building the backend for a growing SaaS platform called **Vaultly**. The platform allows teams to subscribe to different plans (Free, Pro, Enterprise) and tracks billing activity over time. The engineering team follows a Phoenix context-based architecture, meaning all database operations live in context modules — never in controllers or LiveViews.

The current codebase has no subscription functionality yet. A product manager has filed the following requirements:

1. **Atomic subscription creation**: When a user subscribes, the system must create both a `Subscription` record and a corresponding `BillingRecord` in the same atomic operation. Either both are created successfully or neither is — partial state is unacceptable. If creation fails (e.g. due to validation errors), the caller must be able to tell *which step* failed so the API can return a useful error message.

2. **Plan upsert**: The system needs to seed and keep plan definitions current without manual database management. Plans are identified by a unique short code (e.g. `"pro"`, `"enterprise"`). The upsert function should create the plan if it does not exist, or update its attributes if it already does.

3. **Subscription event logging**: Various parts of the system need to attach timestamped events to a subscription (e.g. `"trial_started"`, `"payment_failed"`, `"upgraded"`). Given an existing subscription struct, the system should create a linked `SubscriptionEvent` record using the association already present on the subscription.

## What to Build

Implement the following Elixir source files for the `MyApp.Subscriptions` context:

- `lib/my_app/subscriptions/subscription.ex` — Ecto schema for `subscriptions` table. Fields: `user_id` (integer), `plan_code` (string), `status` (string, e.g. `"active"`, `"cancelled"`), `started_at` (naive_datetime). Include associations and timestamps.
- `lib/my_app/subscriptions/billing_record.ex` — Ecto schema for `billing_records` table. Fields: `subscription_id` (integer, foreign key), `amount_cents` (integer), `currency` (string), `description` (string). Include associations and timestamps.
- `lib/my_app/subscriptions/plan.ex` — Ecto schema for `plans` table. Fields: `code` (string, unique), `name` (string), `price_cents` (integer). Include timestamps.
- `lib/my_app/subscriptions/subscription_event.ex` — Ecto schema for `subscription_events` table. Fields: `subscription_id` (integer, foreign key), `event_type` (string), `metadata` (map). Include associations and timestamps.
- `lib/my_app/subscriptions.ex` — The public context module exposing:
  - `subscribe_user(user_id, plan_attrs)` — atomically creates a Subscription and an initial BillingRecord, returning a success or failure tuple that identifies which step failed when things go wrong.
  - `upsert_plan(attrs)` — creates or updates a Plan, keyed on the plan's `code` field.
  - `add_subscription_event(subscription, event_attrs)` — creates a SubscriptionEvent linked to the given subscription struct.

Include appropriate changeset functions in each schema module with validation of required fields.
