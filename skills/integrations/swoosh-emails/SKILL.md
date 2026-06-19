---
name: swoosh-emails
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when sending emails from Phoenix applications. Invoke before implementing email functionality.
  Covers Swoosh setup, email templates, delivery configuration, testing, and production adapters.
  Trigger words: email, Swoosh, mailer, email templates, SMTP, SendGrid, email testing.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Swoosh Emails

Swoosh is the standard email library for Elixir/Phoenix applications.

## RULES — Follow these with no exceptions

1. **Use Swoosh for all email sending** — the standard library with adapter support for all providers
2. **Define emails in separate modules** — `MyApp.Emails.UserEmail`, not inline in contexts
3. **Use Phoenix components for email templates** — reuse UI components in emails
4. **Configure delivery per environment** — Local adapter in dev/test, real adapter in prod
5. **Test emails with Swoosh.TestAssertions** — assert emails were sent with correct content
6. **Never send emails synchronously in web requests** — use Oban or Task for async delivery
7. **Use `Swoosh.Preview` in development** — preview emails in the browser
8. **Prefer Oban over Task.start for async delivery** — `Task.start` silently drops errors on failure; Oban provides retries and observability

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:swoosh, "~> 1.14"},
    {:finch, "~> 0.18"},  # Required for HTTP-based adapters
    {:gen_smtp, "~> 1.0"}  # Required for SMTP adapter
  ]
end

# application.ex
def start(_type, _args) do
  children = [
    # ...
    {Finch, name: MyApp.Finch}  # Required for Swoosh — must be present or HTTP adapters will crash
  ]
  # ...
end
```

### Validate Setup

After adding deps and configuring the supervision tree, confirm everything works before writing email modules:

```elixir
# In iex -S mix (dev environment with Local adapter)
MyApp.Mailer.deliver(Swoosh.Email.new(to: "test@example.com", from: "noreply@myapp.com", subject: "Test"))
# => {:ok, %{}} means Finch is running and the mailer is configured correctly
# => {:error, ...} means Finch is missing from the supervision tree or adapter is misconfigured
```

---

## Defining Emails

```elixir
# lib/my_app/emails/user_email.ex
defmodule MyApp.Emails.UserEmail do
  import Swoosh.Email

  def welcome(user) do
    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "noreply@myapp.com"})
    |> subject("Welcome to MyApp!")
    |> html_body("""
      <h1>Welcome, #{user.name}!</h1>
      <p>Thanks for signing up.</p>
    """)
    |> text_body("Welcome, #{user.name}! Thanks for signing up.")
  end

  def password_reset(user, token) do
    reset_link = MyAppWeb.Router.Helpers.reset_url(MyAppWeb.Endpoint, :edit, token)

    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "noreply@myapp.com"})
    |> subject("Reset your password")
    |> html_body("""
      <h1>Reset your password</h1>
      <p><a href=\"#{reset_link}\">Reset Password</a></p>
    """)
    |> text_body("Reset your password: #{reset_link}")
  end
end
```

> For component-based templates (reusing Phoenix HEEx components), use `Phoenix.Component.render_component/2` and define a dedicated template module. Keep the email module itself focused on composing the `Swoosh.Email` struct.

---

## Mailer Module

```elixir
# lib/my_app/mailer.ex
defmodule MyApp.Mailer do
  use Swoosh.Mailer, otp_app: :my_app
end
```

---

## Configuration

```elixir
# config/config.exs
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Local

# config/dev.exs
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Local

# Enable preview server
config :swoosh, serve: true

# config/test.exs
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Test

# config/prod.exs (or runtime.exs)
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY")

# Or SMTP
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :if_available
```

---

## Sending Emails

### With Oban (Recommended for Production)

Oban persists jobs to the database, retries on failure, and surfaces errors via job monitoring — prefer it over `Task.start` whenever delivery failures matter.

```elixir
defmodule MyApp.Workers.SendWelcomeEmail do
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = Accounts.get_user!(user_id)

    user
    |> MyApp.Emails.UserEmail.welcome()
    |> MyApp.Mailer.deliver()

    {:ok, :sent}
  end
end

# Enqueue from context
def register_user(attrs) do
  with {:ok, user} <- create_user(attrs) do
    %{user_id: user.id}
    |> MyApp.Workers.SendWelcomeEmail.new()
    |> Oban.insert()

    {:ok, user}
  end
end
```

### With Task (Simple Cases Only)

Use `Task.start` only for non-critical emails where silent failure is acceptable. Errors are not logged or retried.

```elixir
# In a context module
defmodule MyApp.Accounts do
  alias MyApp.Emails.UserEmail
  alias MyApp.Mailer

  def register_user(attrs) do
    with {:ok, user} <- create_user(attrs) do
      # Fire-and-forget — errors are silently dropped
      Task.start(fn ->
        user |> UserEmail.welcome() |> Mailer.deliver()
      end)

      {:ok, user}
    end
  end
end
```

---

## Testing Emails

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true

  import Swoosh.TestAssertions

  test "sends welcome email on registration" do
    attrs = %{email: "test@example.com", password: "password123"}

    assert {:ok, user} = Accounts.register_user(attrs)

    # Assert email was sent
    assert_email_sent(fn email ->
      assert email.to == [{user.name, user.email}]
      assert email.subject =~ "Welcome"
    end)
  end

  test "no email sent on failed registration" do
    attrs = %{email: "", password: ""}

    assert {:error, _changeset} = Accounts.register_user(attrs)

    assert_no_email_sent()
  end
end
```

---

## Email Preview in Development

```elixir
# config/dev.exs
config :swoosh, serve: true

# Access preview at http://localhost:4000/dev/mailbox
```

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| **oban-essentials** | For async email delivery |
| **testing-essentials** | For email testing patterns |
| **phoenix-liveview-essentials** | For email form UI |
