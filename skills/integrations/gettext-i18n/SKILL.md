---
name: gettext-i18n
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when implementing internationalization (i18n) in Elixir/Phoenix applications. Invoke before
  adding translations or supporting multiple languages. Covers Gettext setup, translation functions,
  pluralization, locale management, and .po/.pot file workflows.
  Trigger words: gettext, i18n, internationalization, translation, locale, pluralization, multiple languages.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Gettext Internationalization

Gettext is the standard internationalization library for Elixir/Phoenix applications.

## End-to-End Workflow

1. **Add Gettext calls** — wrap strings with `gettext/1`, `dgettext/2`, or `ngettext/3` in templates, LiveView, and controllers
2. **Extract strings** — run `mix gettext.extract --merge` to generate/update `.pot` and `.po` files
3. **Verify `.po` files** — confirm new `msgid` entries appear with empty `msgstr` values
4. **Add translations** — fill in `msgstr` values for each target locale
5. **Set locale per request** — configure a plug or LiveView mount to call `Gettext.put_locale/1`
6. **Test** — assert translated strings appear when locale is set

---

## RULES — Follow these with no exceptions

1. **Set locale per request** — use `Gettext.put_locale/1` in plugs or LiveView mount
2. **Don't translate error messages meant for logs** — only translate user-facing text
3. **Use domain-specific contexts** — `dgettext("errors", "Not found")` for different domains

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:gettext, "~> 0.26"}
  ]
end
```

---

## Gettext Module

```elixir
# lib/my_app_web/gettext.ex
defmodule MyAppWeb.Gettext do
  use Gettext.Backend, otp_app: :my_app
end
```

---

## Using Translations

### In Templates

```heex
<h1><%= gettext("Welcome to our site") %></h1>

<p>
  <%= gettext("You have %{count} new messages", count: @message_count) %>
</p>

<%# Pluralization: pass count as both the integer and a binding %>
<%= ngettext("There is %{count} item", "There are %{count} items", @item_count, count: @item_count) %>
```

### In LiveView

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  import MyAppWeb.Gettext

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    Gettext.put_locale(MyAppWeb.Gettext, locale)

    {:ok, assign(socket, :greeting, gettext("Hello!"))}
  end
end
```

### In Controllers

```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller
  import MyAppWeb.Gettext

  def index(conn, _params) do
    message = gettext("Welcome to %{app_name}", app_name: "MyApp")
    render(conn, :index, message: message)
  end
end
```

---

## Domain-Specific Translations

```elixir
gettext("Save")                              # Default domain
dgettext("errors", "Not found")             # Errors domain
dgettext("emails", "Welcome email subject") # Emails domain
```

---

## Translation Files

### Directory Structure

```
priv/gettext/
├── en/LC_MESSAGES/
│   ├── default.po      # Default domain
│   └── errors.po       # Errors domain
├── es/LC_MESSAGES/
│   ├── default.po
│   └── errors.po
└── default.pot         # Template file
```

### PO File Format

```po
# priv/gettext/es/LC_MESSAGES/default.po
msgid "Welcome to our site"
msgstr "Bienvenido a nuestro sitio"

msgid "You have %{count} new message"
msgid_plural "You have %{count} new messages"
msgstr[0] "Tienes %{count} mensaje nuevo"
msgstr[1] "Tienes %{count} mensajes nuevos"
```

---

## Extracting Translations

```bash
# Extract new strings to .pot files
mix gettext.extract

# Merge .pot files into .po files
mix gettext.merge priv/gettext

# Extract and merge in one step
mix gettext.extract --merge
```

**Validate:** After extraction, open the relevant `.po` files and confirm new `msgid` entries appear with empty `msgstr` values. Fill in translations before deploying.

---

## Setting Locale

```elixir
# lib/my_app_web/plugs/set_locale.ex
defmodule MyAppWeb.Plugs.SetLocale do
  import Plug.Conn

  @supported_locales ~w(en es fr de)

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      locale_from_params(conn) ||
      locale_from_session(conn) ||
      locale_from_header(conn) ||
      "en"

    Gettext.put_locale(MyAppWeb.Gettext, locale)
    conn
  end

  defp locale_from_params(conn) do
    conn.params["locale"]
    |> validate_locale()
  end

  defp locale_from_session(conn) do
    conn
    |> get_session("locale")
    |> validate_locale()
  end

  defp locale_from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_accept_language()
    |> validate_locale()
  end

  defp parse_accept_language(nil), do: nil

  defp parse_accept_language(header) do
    # Take the first (highest-priority) locale tag, e.g. "es-MX,es;q=0.9" -> "es"
    header
    |> String.split(",")
    |> List.first()
    |> String.split("-")
    |> List.first()
    |> String.trim()
  end

  defp validate_locale(locale) when locale in @supported_locales, do: locale
  defp validate_locale(_), do: nil
end
```

Register it in the router pipeline:

```elixir
pipeline :browser do
  # ...
  plug MyAppWeb.Plugs.SetLocale
end
```

---

## Testing Translations

```elixir
defmodule MyAppWeb.PageTest do
  use MyAppWeb.ConnCase

  test "renders translated welcome message", %{conn: conn} do
    Gettext.put_locale(MyAppWeb.Gettext, "es")

    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ "Bienvenido"
  end
end
```
