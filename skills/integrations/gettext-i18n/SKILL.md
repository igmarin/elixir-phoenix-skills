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

---

# Gettext Internationalization

## End-to-End Workflow

1. **Add Gettext calls** — wrap strings with `gettext/1`, `dgettext/2`, or `ngettext/3` in templates, LiveView, and controllers
2. **Extract strings** — run `mix gettext.extract --merge` to generate/update `.pot` and `.po` files
3. **Verify `.po` files** — confirm new `msgid` entries appear with empty `msgstr` values
4. **Add translations** — fill in `msgstr` values for each target locale
5. **Set locale per request** — configure a plug or LiveView mount to call `Gettext.put_locale/2`
6. **Test** — assert translated strings appear when locale is set


## Key Rules

- **Only translate user-facing text** — not log-only error messages
- **Use domain-specific contexts** — `dgettext("errors", "Not found")` keeps error strings in a separate `.po` file from default content


## Setup

```elixir
# mix.exs — add dependency
{:gettext, "~> 0.26"}

# lib/my_app_web/gettext.ex — define backend
defmodule MyAppWeb.Gettext do
  use Gettext.Backend, otp_app: :my_app
end
```


## Using Translations

`import MyAppWeb.Gettext`, then call `gettext/1`, `dgettext/2`, or `ngettext/3`.

```elixir
defmodule MyAppWeb.HomeLive do
  use MyAppWeb, :live_view
  import MyAppWeb.Gettext

  @impl true
  def mount(_params, session, socket) do
    locale = session["locale"] || "en"
    Gettext.put_locale(MyAppWeb.Gettext, locale)

    socket =
      socket
      |> assign(:greeting, gettext("Hello!"))
      |> assign(:error, dgettext("errors", "Not found"))
      # ngettext: pass count as integer arg and as a binding
      |> assign(:summary,
           ngettext("There is %{count} item", "There are %{count} items",
                    @item_count, count: @item_count))

    {:ok, socket}
  end
end
```

```heex
<h1><%= gettext("Welcome to %{app_name}", app_name: "MyApp") %></h1>
```


## Translation Files

Locale files live under `priv/gettext/<locale>/LC_MESSAGES/<domain>.po`; the shared template is `priv/gettext/<domain>.pot`.

```po
# priv/gettext/es/LC_MESSAGES/default.po
msgid "You have %{count} new message"
msgid_plural "You have %{count} new messages"
msgstr[0] "Tienes %{count} mensaje nuevo"
msgstr[1] "Tienes %{count} mensajes nuevos"
```


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


## Setting Locale

The recommended pattern is a plug that resolves locale from params → session → default, then calls `Gettext.put_locale/2`:

```elixir
# lib/my_app_web/plugs/set_locale.ex
defmodule MyAppWeb.Plugs.SetLocale do
  import Plug.Conn

  @supported_locales ~w(en es fr de)

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      get_locale_from_params(conn) ||
      get_locale_from_session(conn) ||
      "en"

    Gettext.put_locale(MyAppWeb.Gettext, locale)
    conn
  end

  defp get_locale_from_params(conn), do: validate(conn.params["locale"])
  defp get_locale_from_session(conn), do: validate(get_session(conn, "locale"))

  defp validate(locale) when locale in @supported_locales, do: locale
  defp validate(_), do: nil
end
```

Register it in the router pipeline:

```elixir
pipeline :browser do
  # ...
  plug MyAppWeb.Plugs.SetLocale
end
```


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
