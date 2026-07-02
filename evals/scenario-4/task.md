# Notes API — Backend Implementation

## Problem/Feature Description

Notara is a note-taking SaaS that has been running as a full Phoenix web app (HTML/LiveView). The product team has approved a mobile client, and the mobile engineering team needs a JSON API to support it. The existing app already has user authentication and a notes context (`MyApp.Notes`) with basic CRUD, but the API surface doesn't exist yet.

You've been handed the story: implement the JSON API layer so the mobile team can build against it. The API must support listing a user's notes (with optional keyword search and pagination), retrieving a single note, creating a note, and deleting a note. Authentication is via Bearer tokens that clients send in the `Authorization` header. The mobile team will be calling these endpoints from devices with variable connectivity, so the API must return consistent, predictable JSON error shapes for all failure modes.

A known previous incident involved a text-search endpoint that was built by concatenating user input directly into a query string, which caused a security regression when the feature shipped. The team lead has asked that whoever implements this takes care to avoid that class of bug — the search term comes from untrusted user input.

## Output Specification

Implement the following Elixir source files. Do not create a mix project scaffold — write only the application source files:

- `lib/my_app_web/router.ex` — router with the appropriate pipeline and versioned route scope
- `lib/my_app_web/controllers/fallback_controller.ex` — handles error tuples and renders consistent JSON error responses
- `lib/my_app_web/controllers/api/v1/notes_controller.ex` — controller with `index`, `show`, `create`, and `delete` actions
- `lib/my_app_web/plugs/api_auth.ex` — a Plug that extracts and verifies the Bearer token from the `Authorization` header
- `lib/my_app/notes.ex` — context module with `list_notes/2` (supports search and pagination), `get_note/2`, `create_note/2`, and `delete_note/2`

Write a `notes_api_summary.md` file summarising the design decisions made in the implementation (pipeline choice, versioning approach, error handling pattern, query safety approach, auth token comparison approach).
