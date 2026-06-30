# Welcome Email Pipeline

## Problem Description

Your team has just shipped user registration for a new Phoenix application. Currently, after a user signs up, the `Accounts.register_user/1` context function creates the user record and returns. The product team wants a welcome email sent to every new user to confirm their account and introduce key features.

The engineering lead has flagged two requirements. First, the email delivery must not slow down the registration response — users should get their confirmation page immediately, and the email should happen in the background. Second, the system must be resilient to retries: if the job queue is flushed or a node restarts, no user should receive duplicate welcome emails, and missing users (already deleted) should not cause the worker to crash-loop.

Your task is to implement the full welcome email pipeline from registration through delivery. This means writing the Oban worker that sends the email, a dedicated email module that constructs the welcome message, updating the `Accounts` context to schedule the job when a user is registered, and a test file that covers all execution paths of the worker.

The codebase uses Phoenix with Ecto for persistence, Swoosh for email, and Oban for background job processing. The `User` schema has the fields `:id`, `:email`, and `:name`. The Swoosh mailer is already configured and accessible as `MyApp.Mailer`.

## Output Specification

Write the following files:

- `lib/my_app/workers/send_welcome_email.ex` — the Oban worker module
- `lib/my_app/emails/user_email.ex` — the email construction module
- `lib/my_app/accounts.ex` — the context module, including `register_user/1`
- `test/my_app/workers/send_welcome_email_test.exs` — ExUnit tests covering the worker

The worker should handle the case where the user no longer exists in the database gracefully (do not keep retrying). Use `Oban.Worker` with a queue of `:mailer`.

For the purpose of this implementation, you may define a minimal `MyApp.Accounts.User` struct or Ecto schema with the fields needed (`:id`, `:email`, `:name`) and a stub `get_user/1` function if a full Ecto setup would be out of scope — the grader will assess the structure and patterns used, not whether the code compiles against a live database.
