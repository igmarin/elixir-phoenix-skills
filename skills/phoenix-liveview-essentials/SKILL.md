---
name: phoenix-liveview-essentials
type: atomic
description: Use when building or changing a Phoenix LiveView, event handler, form, navigation flow, or LiveView test.
metadata:
  user-invocable: "true"
---

# Phoenix LiveView Essentials

Keep the LiveView as the UI edge. Parse events and params, call domain/context functions, then assign results or show errors. Keep business rules out of callbacks.

## Lifecycle and data

- `mount/3` may run for the disconnected HTTP render and again for the connected socket. Keep it safe to repeat; subscribe or start live work only when `connected?/1` is true.
- Put route-dependent loading in `handle_params/3`. Use `push_patch` for same-LiveView state and `push_navigate` for a new LiveView.
- Keep assigns limited to data needed by the render. Use streams for large or frequently updated collections.
- Load records through the application's authorization boundary; a guessed ID is not proof of access.

## Events and forms

- Treat all event params as untrusted strings/maps. Validate with a changeset or domain parser before writing.
- `handle_event/3` should coordinate work and update the socket. Move multi-step rules into a context or pure module.
- For forms, use `to_form/1` and the project's current form conventions. Preserve changeset errors and keep validation behavior in the changeset.
- Use tagged results to render expected failures. Let unexpected failures surface to normal error reporting.

## Failure paths and UI state

- **Repeat clicks:** every writing button gets `phx-disable-with`. A second click must not repeat or invert the action (e.g. toggle review → back to pending).
- **Stale targets:** handlers must tolerate a record that is nil or no longer in the list (`ask_cancel` with an old id). Do not let `_ ->` show a message that may be false ("already cancelled"); match the real result or the real changeset field.
- **Reads that can fail:** rescue only the expected infra errors (`DBConnection.ConnectionError`, `DBConnection.OwnershipError`, `Postgrex.Error`) and log with `__STACKTRACE__`. A bare `rescue error ->` turns code bugs into "could not load".
- **After reload events:** recompute every derived assign (counters, figures, open `editing` struct and form). A refresh that leaves the form open on an old struct causes false `:stale` errors on save.
- **Assign before you read:** set filter/page assigns before the load, so an error render shows the filters the user asked for.
- **Confirmations:** `data-confirm` works only if the app registers a handler (check `app.js`); otherwise use an explicit confirm step in the LiveView.
- **Attribute values:** HEEx does not serialize booleans for `phx-value-*`; pass `to_string/1` and parse explicitly.
- **Per-keystroke events:** keep `phx-change` handlers cheap; do not run heavy queries on each keypress.
- **Size:** keep a component under ~400 lines; move labels and pure helpers to their own modules.
- **Dates:** show times in the user's zone, not the stored UTC day.

## Tests

Cover initial render, relevant events, invalid input, authorization, and navigation that changes behavior. Use `Phoenix.LiveViewTest` and the existing ConnCase/DataCase setup. Avoid duplicating assertions already covered by component or context tests.

For large lists use `liveview-streams`; for auth flows use `phoenix-authentication` and `phoenix-authorization-patterns`.
