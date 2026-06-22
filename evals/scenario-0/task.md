# Blog Comments: Implement the Comments Context

## Problem/Feature Description

The engineering team at a growing blogging platform is expanding the system to support reader comments. Posts already exist in the database, but the product team now wants users to be able to leave comments that go through a moderation workflow before appearing publicly. A comment has a body (the reader's message), the author's display name, and a status that tracks where it is in the moderation pipeline.

You have been asked to implement the `Comments` context for the `Blog` application. This includes the Ecto schema, a database migration, and a full context module that the rest of the application (including Phoenix controllers and LiveViews) will call to manage comment data. The `Post` schema and its migration already exist — your `Comment` records must associate with posts.

The status field represents where a comment sits in moderation and must be restricted to specific allowed values. Comments also need appropriate database-level safeguards in addition to changeset validation, and the migration should be written so it can be safely applied, rolled back, and re-applied.

## Output Specification

Produce the following files in a Phoenix-style directory layout (use `MyApp` as the application name):

- `lib/my_app/blog/comment.ex` — the Ecto schema and changeset
- `lib/my_app/blog.ex` — the Blog context module with CRUD functions for comments
- `priv/repo/migrations/<timestamp>_create_comments.exs` — the Ecto migration (use any reasonable timestamp prefix)
- `MIGRATION_NOTES.md` — a short markdown file documenting the exact shell commands you would run to validate the migration (apply, rollback, re-apply), and what successful output looks like at each step

Do not include a running database — the grader will read the source files directly.
