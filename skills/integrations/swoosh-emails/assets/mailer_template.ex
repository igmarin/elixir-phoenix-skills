# Swoosh Mailer + Email Builder Template
#
# Copy-paste templates for a Swoosh Mailer module and an email-builder module.
# Referencing modules such as Swoosh.Email/Oban that are undefined here is fine —
# only the syntax of this file is checked.

defmodule MyApp.Mailer do
  @moduledoc "Application mailer. Adapter is configured per environment in config/*.exs."
  use Swoosh.Mailer, otp_app: :my_app
end

defmodule MyApp.Emails.UserEmail do
  @moduledoc """
  Email builders live in their own module — never inline inside contexts.

  Each builder returns a `%Swoosh.Email{}` struct; delivery happens elsewhere
  (an Oban worker in production) so the web request never blocks on SMTP.
  """
  import Swoosh.Email

  @from {"MyApp", "noreply@myapp.com"}

  @doc "Welcome email sent after registration. Always sets both html and text bodies."
  def welcome(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Welcome to MyApp!")
    |> html_body(welcome_html(user))
    |> text_body("Welcome, #{user.name}! Thanks for signing up.")
  end

  @doc "Password reset email with a signed, expiring token URL."
  def password_reset(user, reset_url) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Reset your password")
    |> html_body("""
    <p>Hi #{user.name},</p>
    <p>Click <a href="#{reset_url}">here</a> to reset your password.</p>
    """)
    |> text_body("Reset your password: #{reset_url}")
  end

  defp welcome_html(user) do
    """
    <h1>Welcome, #{user.name}!</h1>
    <p>Thanks for signing up.</p>
    """
  end
end

defmodule MyApp.Workers.SendWelcomeEmail do
  @moduledoc "Deliver the welcome email asynchronously via Oban."
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    user = MyApp.Accounts.get_user!(user_id)

    user
    |> MyApp.Emails.UserEmail.welcome()
    |> MyApp.Mailer.deliver()

    {:ok, :sent}
  end
end
