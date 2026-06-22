# Migration Conventions

This project follows standard Ecto migration practices. When adding new columns or tables:

- Generate migration files with `mix ecto.gen.migration <name>`.
- Each migration file lives in `priv/repo/migrations/` with a timestamp prefix.
- Migrations should be reversible — always implement both the `up` direction and a clean `down`.
- After authoring a migration, verify it with the standard workflow before committing.

## Project Structure

```
lib/
  my_app/
    blog/
      article.ex        ← Ecto schema + changeset
priv/
  repo/
    migrations/
      <timestamp>_create_articles.exs
      ...
```

## Existing Articles Table

The `articles` table was created with the following columns:

| Column      | Type    | Notes                          |
|-------------|---------|--------------------------------|
| id          | bigint  | Primary key                    |
| title       | string  | Required, max 255 chars        |
| body        | text    | Required                       |
| author_id   | bigint  | FK → users.id                  |
| inserted_at | naive_datetime | Ecto timestamps         |
| updated_at  | naive_datetime | Ecto timestamps         |

There are currently several hundred articles in the database with no `slug` values.
