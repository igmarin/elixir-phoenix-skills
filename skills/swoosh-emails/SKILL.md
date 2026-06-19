---
name: swoosh-emails
type: atomic
license: MIT
description: >
  Use when sending emails from Phoenix applications. Invoke before implementing email functionality.
  Covers Swoosh setup, email templates, delivery configuration, testing, and production adapters.
  Trigger words: email, Swoosh, mailer, email templates, SMTP, SendGrid, email testing.
metadata:
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
    {Finch, name: MyApp.Finch}  # Required for Swoosh
  ]
  # ...
end
```

---

## Defining Emails

```elixir
# lib/my_app/emails/user_email.ex
defmodule MyApp.Emails.UserEmail do
  import Swoosh.Email
  use Phoenix.Component

  def welcome(user) do
    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "noreply@myapp.com"})
    |> subject("Welcome to MyApp!")
    |> render_body("welcome.html", %{user: user})
  end

  def password_reset(user, token) do
    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "noreply@myapp.com"})
    |> subject("Reset your password")
    |> render_body("password_reset.html", %{user: user, token: token})
  end

  defp render_body(email, template, assigns) do
    email
    |> html_body(render_html(template, assigns))
    |> text_body(render_text(template, assigns))
  end

  defp render_html(template, assigns) do
    render_component(&html_template/1, Map.put(assigns, :template, template))
  end

  defp html_template(%{template: "welcome.html", user: user} = assigns) do
    ~H"""
    <h1>Welcome, <%= @user.name %>!</h1>
    <p>Thanks for signing up.</p>
    """
  end

  defp html_template(%{template: "password_reset.html", user: user, token: token} = assigns) do
    ~H"""
    <h1>Reset your password</h1>
    <p>Click the link below to reset your password:</p>
    <a href={reset_url(@token)}>Reset Password</a>
    """
  end
end
```

---

## Mailer Module

```elixir
# lib/my_app/mailer.ex
defmodule MyApp.Mailer do
  use Swoosh.Mailer, otp_app: :my_app

  # Optional: add default from address
  def deliver(email) do
    email
    |> put_provider_option(:template_id, "welcome_template")
    |> super()
  end
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

```elixir
# In a context module
defmodule MyApp.Accounts do
  alias MyApp.Emails.UserEmail
  alias MyApp.Mailer

  def register_user(attrs) do
    with {:ok, user} <- create_user(attrs) do
      # Send email asynchronously
      Task.start(fn ->
        user |> UserEmail.welcome() |> Mailer.deliver()
      end)

      {:ok, user}
    end
  end
end
```

### With Oban (Recommended for Production)

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

## Common Pitfalls

❌ **Don't** send emails synchronously in web requests
❌ **Don't** define emails inline in contexts
❌ **Don't** forget to configure test adapter
❌ **Don't** hardcode email addresses — use config
❌ **Don't** forget to add Finch to supervision tree

✅ **Do** use Swoosh for all email sending
✅ **Do** define emails in separate modules
✅ **Do** use Oban for async delivery in production
✅ **Do** test with `Swoosh.TestAssertions`
✅ **Do** use preview server in development

## Integration

| Skill | When to chain |
|-------|---------------|
| **oban-essentials** | For async email delivery |
| **testing-essentials** | For email testing patterns |
| **phoenix-liveview-essentials** | For email form UI |
