# Blog Module Test Suite

## Problem/Feature Description

Your team has been building a Phoenix blog feature for `MyApp`. The core context module (`MyApp.Blog`) and its associated Ecto schema (`MyApp.Blog.Post`) have been written by another developer and are stored in the `inputs/` directory. There's also a LiveView index page (`MyAppWeb.PostLive.Index`) that lists posts belonging to the currently authenticated user and allows them to delete posts.

Before this code can be merged, it needs a comprehensive ExUnit test suite. You've been handed the stub implementation files and asked to write tests covering the Blog context functions (`create_post/1`, `update_post/2`, `delete_post/1`, `list_posts/1`) and the `PostLive.Index` LiveView page. The codebase is a standard Phoenix project — `DataCase` and `ConnCase` are already defined in `test/support/` and you may use `MyApp.Repo` and the standard sandbox setup without implementing them yourself.

The team cares that the test suite is maintainable and production-ready: tests should not be flaky and the suite should cover both the happy path and edge cases, including scenarios where a user is not logged in or does not own the resource they are trying to act on.

## Output Specification

Write ExUnit test files covering the `MyApp.Blog` context and the `MyAppWeb.PostLive.Index` LiveView. Also write any supporting test helper files you need.

Name each output file according to standard Phoenix project conventions. Do not include `mix.exs`, config files, or migration files.

The test files should be written as if they belong to a real Phoenix project. Reference the source modules in `inputs/` (e.g., `MyApp.Blog`, `MyApp.Blog.Post`, `MyAppWeb.PostLive.Index`) as the subjects under test.
