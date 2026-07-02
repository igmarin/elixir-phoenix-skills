# User Record Pipeline: Property Testing

## Problem Description

Your team maintains a `DataTransformer` module that handles user record normalization and filtering for a multi-tenant SaaS platform. The module processes batches of user records — normalizing email addresses, filtering out inactive accounts, and merging duplicate profiles from different sources. The implementation has grown organically and now needs a solid test suite before a planned refactor.

The engineering lead has asked you to write a comprehensive test suite that will hold up even if the internal implementation is rewritten. Rather than brittle tests that check "given these exact 3 users, expect this exact result," the team wants tests that verify the behavioral contracts of the module — invariants that must hold for *any* valid input. The test suite should be resilient to implementation changes as long as the contracts are preserved.

You need to:

1. Write the `DataTransformer` module at `lib/my_app/data_transformer.ex` with the following public functions:
   - `normalize_email(user)` — returns `{:ok, updated_user}` with the email lowercased and trimmed, or `{:error, reason}` if the user has no email
   - `filter_active_users(users)` — returns only users where `active: true`
   - `merge_profiles(profile_a, profile_b)` — merges two user profile maps, with `profile_b` fields taking precedence for conflicts, returns `{:ok, merged}` or `{:error, reason}` if either profile is missing a required `:id` field

2. Write a property-based test suite at `test/my_app/data_transformer_test.exs` that tests the behavioral invariants of each function using generated inputs rather than hand-crafted examples.

The project already has `stream_data` in its dependencies. A minimal `mix.exs` is provided in the `inputs/` directory for reference — you can create the source and test files directly without running `mix new`.

## Output Specification

Produce two files:

- `lib/my_app/data_transformer.ex` — the `DataTransformer` module implementation
- `test/my_app/data_transformer_test.exs` — the property-based test suite covering all three public functions

The test suite should be robust enough that it would catch regressions even if the internal implementation is rewritten, as long as the behavioral contracts are preserved. Tests should not be tied to specific hand-crafted values.

You do **not** need to run the tests — just produce the source files.
