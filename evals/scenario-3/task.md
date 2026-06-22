# Add SEO-Friendly Slugs to the Articles Table

## Problem/Feature Description

The marketing team has requested that all blog articles get SEO-friendly URL slugs. Currently, the application routes articles by numeric ID (e.g. `/articles/42`), which performs poorly in search rankings and makes URLs opaque to readers. The goal is to introduce a `slug` column on the `articles` table so that articles can be addressed by a human-readable identifier like `/articles/my-first-post`.

The existing `articles` table already has `title`, `body`, `author_id` (a foreign key to the `users` table), and `timestamps`. There are live rows in production — every article must get a slug derived from its title once the column exists. Slugs must be globally unique so there are no routing collisions.

You have been handed the current Article schema module at `inputs/article.ex` and a stub migration file `inputs/MIGRATION_GUIDE.md` that explains the project conventions. Your job is to produce the migrations and the updated schema module so the team can ship the feature.

## Output Specification

Produce the following files in your working directory:

- `priv/repo/migrations/<timestamp>_add_slug_to_articles.exs` — a migration that adds the `slug` column to the `articles` table and enforces uniqueness at the database level.
- `priv/repo/migrations/<timestamp>_backfill_article_slugs.exs` — a **separate** migration that populates the `slug` column for all existing rows using the article title.
- `lib/my_app/blog/article.ex` — the updated Ecto schema module reflecting the new field with proper changeset validation.
- `MIGRATION_NOTES.md` — a document describing the validation steps you ran (or would run) on each migration to confirm it applies and rolls back cleanly.

Use realistic timestamps in migration filenames (e.g. `20240601120000`). The two migrations must have different timestamps so they sort and run in the correct order.
