---
name: gettext-i18n
type: atomic
tags: [atomic]
license: MIT
description: >
  Use when implementing internationalization (i18n) in Elixir/Phoenix applications. Invoke before
  adding translations or supporting multiple languages. Covers Gettext setup, translation functions,
  pluralization, and locale management.
  Trigger words: gettext, i18n, internationalization, translation, locale, pluralization, multiple languages.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Gettext Internationalization

Gettext is the standard internationalization library for Elixir/Phoenix applications.

## RULES — Follow these with no exceptions

1. **Use Gettext for all user-facing strings** — never hardcode strings in templates or code
2. **Wrap strings with `gettext/1` or `dgettext/2`** — mark all translatable text
3. **Use pluralization for counts** — `ngettext/3` handles singular/plural forms
4. **Extract translations regularly** — run `mix gettext.extract` after adding new strings
5. **Set locale per request** — use `Gettext.put_locale/1` in plugs or LiveView mount
6. **Don't translate error messages meant for logs** — only translate user-facing text
7. **Use domain-specific contexts** — `dgettext("errors", "Not found")` for different domains

---

## Setup

```elixir
# mix.exs
defp deps do
  [
    {:gettext, "~> 0.26"}
  ]
end

# Already included in new Phoenix projects
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

<%= ngettext("There is %{count} item", "There are %{count} items", @item_count, count: @item_count) %>
```

### In LiveView

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  import MyAppWeb.Gettext

  @impl true
  def mount(_params, session, socket) do
    # Set locale from session or default
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
# Use different domains for different contexts
gettext("Save")  # Default domain
dgettext("errors", "Not found")  # Errors domain
dgettext("emails", "Welcome email subject")  # Emails domain
```

---

## Pluralization

```elixir
# Singular and plural forms
ngettext("There is %{count} comment", "There are %{count} comments", @count, count: @count)

# With interpolation
ngettext(
  "You have %{count} new message",
  "You have %{count} new messages",
  @count,
  count: @count
)
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
# priv/gettext/en/LC_MESSAGES/default.po
msgid "Welcome to our site"
msgstr "Welcome to our site"

msgid "You have %{count} new messages"
msgid_plural "You have %{count} new messages"
msgstr[0] "You have %{count} new message"
msgstr[1] "You have %{count} new messages"
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

---

## Setting Locale

### In a Plug

```elixir
defmodule MyAppWeb.Plugs.SetLocale do
  import Plug.Conn
  import MyAppWeb.Gettext

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn
      |> get_locale_from_params()
      |> get_locale_from_session()
      |> get_locale_from_header()
      |> Kernel.||("en")

    Gettext.put_locale(MyAppWeb.Gettext, locale)
    conn
  end

  defp get_locale_from_params(conn) do
    conn.params["locale"]
  end

  defp get_locale_from_session(nil) do
    # Check session
    nil
  end
  defp get_locale_from_session(locale), do: locale

  defp get_locale_from_header(nil) do
    # Check Accept-Language header
    nil
  end
  defp get_locale_from_header(locale), do: locale
end

# In router
pipeline :browser do
  # ...
  plug MyAppWeb.Plugs.SetLocale
end
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

    {:ok, socket}
  end
end
```

---

## Testing Translations

```elixir
defmodule MyAppWeb.PageTest do
  use MyAppWeb.ConnCase

  test "renders translated welcome message", %{conn: conn} do
    # Set locale
    Gettext.put_locale(MyAppWeb.Gettext, "es")

    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ "Bienvenido"
  end
end
```

---

## Common Pitfalls

❌ **Don't** hardcode user-facing strings
❌ **Don't** forget to extract translations after adding strings
❌ **Don't** translate error messages meant for logs
❌ **Don't** forget to set locale per request
❌ **Don't** use string concatenation in translations — use interpolation

✅ **Do** wrap all user-facing strings with `gettext/1`
✅ **Do** use `ngettext/3` for pluralization
✅ **Do** extract and merge translations regularly
✅ **Do** set locale in plugs or LiveView mount
✅ **Do** use interpolation instead of concatenation

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|----------|
| **phoenix-liveview-essentials** | For LiveView locale handling |
| **phoenix-json-api** | For API localization |
| **testing-essentials** | For testing translations |
