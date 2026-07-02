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

## RULES — Follow these with no exceptions

1. **Define emails in separate modules** — `MyApp.Emails.UserEmail`, not inline in contexts
2. **Configure delivery per environment** — Local adapter in dev/test, real adapter in prod
3. **Test emails with Swoosh.TestAssertions** — assert emails were sent with correct content
4. **Never send emails synchronously in web requests** — use Oban for async delivery; use Task.start only for simple cases
5. **Use `Swoosh.Preview` in development** — preview emails in the browser

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:swoosh, "~> 1.14"},
    {:finch, "~> 0.18"},
    {:gen_smtp, "~> 1.0"}
  ]
end

# application.ex
def start(_type, _args) do
  children = [
    # ...
    {Finch, name: MyApp.Finch}
  ]
  # ...
end
```

### Validate Setup

After adding deps and configuring the supervision tree, confirm everything works before writing email modules:

```elixir
# In iex -S mix (dev environment with Local adapter)
MyApp.Mailer.deliver(Swoosh.Email.new(to: "test@example.com", from: "noreply@myapp.com", subject: "Test"))
# => {:ok, %{}} — mailer configured correctly
# => {:error, ...} — Finch missing from supervision tree or adapter misconfigured
```

---

## Defining Emails

### With Phoenix Components (Preferred)

```elixir
# lib/my_app/emails/user_email.ex
defmodule MyApp.Emails.UserEmail do
  import Swoosh.Email
  import Phoenix.Component, only: [sigil_H: 2]
  alias MyAppWeb.EmailComponents

  def welcome(user) do
    assigns = %{user: user}

    html =
      ~H"""
      <EmailComponents.layout>
        <h1>Welcome, <%= @user.name %>!</h1>
        <p>Thanks for signing up.</p>
        <EmailComponents.button href={url(~p"/dashboard")}>Get Started</EmailComponents.button>
      </EmailComponents.layout>
      """
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    new()
    |> to({user.name, user.email})
    |> from({"MyApp", "noreply@myapp.com"})
    |> subject("Welcome to MyApp!")
    |> html_body(html)
    |> text_body("Welcome, #{user.name}! Thanks for signing up.")
  end
end
```

### Email Layout and Button Components

Define reusable components in `lib/my_app_web/components/email_components.ex`. A minimal layout and button:

```elixir
# lib/my_app_web/components/email_components.ex
defmodule MyAppWeb.EmailComponents do
  use Phoenix.Component

  def layout(assigns) do
    ~H"""
    <html>
      <body style="font-family: sans-serif; max-width: 600px; margin: auto;">
        <%= render_slot(@inner_block) %>
      </body>
    </html>
    """
  end

  def button(assigns) do
    ~H"""
    <a href={@href} style="background: #4F46E5; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none;">
      <%= render_slot(@inner_block) %>
    </a>
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
end
```

See [`assets/mailer_template.ex`](assets/mailer_template.ex) for a copy-paste Mailer, email-builder, and Oban delivery worker template.

---

## Configuration

```elixir
# config/dev.exs
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Local

config :swoosh, serve: true

# config/test.exs
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Test

# config/runtime.exs (production)
config :my_app, MyApp.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: System.get_env("SENDGRID_API_KEY")
```

---

## Sending Emails

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

### With Task (Simple Cases Only)

```elixir
def register_user(attrs) do
  with {:ok, user} <- create_user(attrs) do
    Task.start(fn ->
      user |> UserEmail.welcome() |> Mailer.deliver()
    end)

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

| ❌ Don't | ✅ Do |
|----------|-------|
| Build emails inline inside context functions | Define builders in `MyApp.Emails.*` modules |
| `Mailer.deliver/1` synchronously in a web request | Enqueue delivery via an Oban worker |
| Use the Local/prod adapter in the test env | `Swoosh.Adapters.Test` + `Swoosh.TestAssertions` |
| Hardcode the SendGrid API key in config | `System.get_env("SENDGRID_API_KEY")` in `runtime.exs` |
| Send HTML-only emails | Always set both `html_body` and `text_body` |
| Forget `{Finch, name: MyApp.Finch}` in the tree | Add the Finch child before delivering |
| Skip assertions after triggering an email | `assert_email_sent/1` / `assert_no_email_sent/0` |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| oban-essentials | swoosh-emails | testing-essentials |
| ecto-essentials | swoosh-emails | None (standalone) |

**Companion skills:**
- `oban-essentials` — deliver emails asynchronously outside the request cycle
- `testing-essentials` — assert delivery with `Swoosh.TestAssertions`
- `gettext-i18n` — localize subjects and bodies for multi-language mail
