---
name: apply-ecto-conventions
type: atomic
license: MIT
tags: [atomic, quality]
description: >
  Use when writing or reviewing Ecto database code in Elixir applications.
  Enforces consistent patterns for Repo queries, changeset composition,
  preloading strategies, context boundaries, Ecto.Multi transactions, and
  query composition. Covers non-bang vs bang functions, N+1 prevention,
  pagination, and migration safety.
  Trigger words: ecto conventions, repo pattern, changeset, context module,
  preload, ecto query, database conventions, apply ecto patterns.
metadata:
  user-invocable: "true"
  version: 1.0.0
---

# Apply Ecto Conventions

Use this skill when writing or reviewing Ecto database code to ensure consistent, idiomatic patterns.

**Precondition:** Invoke `ecto-essentials` before this skill for the full Ecto reference.

---

## Quick Reference

| Pattern | Convention |
|---------|------------|
| Repo calls | In context modules only — never in LiveViews or controllers |
| Bang functions | `Repo.get!/1` only in tests or when failure is truly unrecoverable |
| Changesets | `cast/4` for permitted fields, `validate_required/3` for constraints |
| Query safety | Parameterized with `^` — never string interpolation in fragments |
| Preloading | Always preload to prevent N+1 |
| Multi | Use `Ecto.Multi` for 2+ related operations |
| Pagination | `offset`/`limit` with composite index |
| Migrations | Reversible `change/0`, expand-contract for column changes |

---

## RULES — Follow these with no exceptions

1. **Never call Repo from LiveViews or controllers** — all database operations belong in context modules
2. **Prefer non-bang functions** in application logic (`Repo.get/1`, `Repo.insert/1`) — use bang only in tests
3. **Parameterize all user input in queries** — use `^` for interpolation, never string concatenation in `fragment`
4. **Always preload associations** outside loops to prevent N+1 queries
5. **Add `foreign_key_constraint` and `unique_constraint`** in changesets to match database constraints
6. **Use Ecto.Multi for 2+ related operations** — never chain multiple Repo calls in sequence without a transaction
7. **Add indexes on foreign keys** and frequently queried columns
8. **Never combine schema changes and data backfill** in the same migration

---

## Context Boundaries: Repo Lives in Contexts

❌ **Bad — Repo called directly in LiveView:**
```elixir
def handle_event("load", _params, socket) do
  users = MyApp.Repo.all(User)  # Direct Repo call!
  {:noreply, assign(socket, :users, users)}
end
```

✅ **Good — LiveView delegates to context:**
```elixir
def handle_event("load", _params, socket) do
  users = Accounts.list_users()
  {:noreply, assign(socket, :users, users)}
end
```

The context module owns Repo:
```elixir
defmodule MyApp.Accounts do
  alias MyApp.Repo
  alias MyApp.Accounts.User

  def list_users, do: Repo.all(User)
  def get_user(id), do: Repo.get(User, id)
end
```

---

## Non-Bang vs Bang Functions

❌ **Bad — bang in application logic (raises on not-found):**
```elixir
def show(conn, %{"id" => id}) do
  user = Repo.get!(User, id)
  render(conn, :show, user: user)
end
```

✅ **Good — non-bang with pattern matching (handles not-found gracefully):**
```elixir
def show(conn, %{"id" => id}) do
  case Accounts.get_user(id) do
    {:ok, user} -> render(conn, :show, user: user)
    {:error, :not_found} -> put_status(conn, :not_found) |> json(%{error: "Not found"})
  end
end
```

The context returns tagged tuples:
```elixir
def get_user(id) do
  case Repo.get(User, id) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end
```

**Checkpoint:** Search for `!` functions in application `lib/` — every one is a potential bug.

---

## Changeset Composition

❌ **Bad — missing database constraints, no validation:**
```elixir
def create_user(attrs) do
  %User{}
  |> Repo.insert(attrs)
end
```

✅ **Good — changeset validates and enforces constraints:**
```elixir
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)
  |> Repo.insert()
end

def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :name])
  |> validate_required([:email, :name])
  |> validate_length(:name, min: 1, max: 255)
  |> validate_format(:email, ~r/@/)
  |> unique_constraint(:email)
  |> foreign_key_constraint(:organization_id)
end
```

---

## Preloading: Prevent N+1

❌ **Bad — N+1 queries inside loop:**
```elixir
users = Repo.all(User)
for user <- users do
  user.posts  # Executes a query per user!
end
```

✅ **Good — preload before iteration:**
```elixir
users = Repo.all(User) |> Repo.preload(:posts)
for user <- users do
  user.posts  # Already loaded — no extra queries
end
```

✅ **Good — nested preloading:**
```elixir
Repo.all(from u in User, preload: [posts: :comments])
```

**Checkpoint:** Run Ecto query log observer in development to detect N+1 violations.

---

## Ecto.Multi for Multi-Step Operations

❌ **Bad — multiple Repo calls without transaction:**
```elixir
def create_user_with_profile(attrs) do
  {:ok, user} = Repo.insert(User.changeset(%User{}, attrs))
  {:ok, profile} = Repo.insert(Profile.changeset(%Profile{}, Map.put(attrs, :user_id, user.id)))
  {:ok, %{user: user, profile: profile}}
end
```

✅ **Good — Ecto.Multi wraps all operations in a transaction:**
```elixir
def create_user_with_profile(user_attrs, profile_attrs) do
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:user, User.changeset(%User{}, user_attrs))
  |> Ecto.Multi.insert(:profile, fn %{user: user} ->
    Profile.changeset(%Profile{}, Map.put(profile_attrs, :user_id, user.id))
  end)
  |> Repo.transaction()
end
```

On failure, `{:error, :user, changeset, _}` identifies the failed step.

---

## Query Composition

❌ **Bad — string interpolation in fragment:**
```elixir
from(u in User, where: fragment("lower(#{field}) = ?", ^value))
```

✅ **Good — parameterized queries with `^`:**
```elixir
from(u in User, where: fragment("lower(?) = ?", field(u, :status), ^value))
from(u in User, where: u.status == ^status and u.name == ^name)
```

### Dynamic Filtering

✅ **Good — Enum.reduce for dynamic where clauses:**
```elixir
def list_users(filters) do
  Enum.reduce(filters, User, fn
    {:status, status}, q -> where(q, status: ^status)
    {:search, term}, q -> where(q, ilike: [name: ^"%#{term}%"])
    _, q -> q
  end)
  |> Repo.all()
end
```

---

## Migrations

❌ **Bad — irreversible migration, no index:**
```elixir
def up do
  alter table(:users) do
    remove :name  # Irreversible!
  end
end
```

✅ **Good — reversible `change/0` with indexes:**
```elixir
def change do
  create table(:images) do
    add :title, :string, null: false
    add :filename, :string, null: false
    add :folder_id, references(:folders, on_delete: :nilify_all)

    timestamps()
  end

  create index(:images, [:folder_id])
  create index(:images, [:inserted_at])
end
```

---

## Pagination

❌ **Bad — no pagination on large tables:**
```elixir
def list_posts, do: Repo.all(Post)
```

✅ **Good — offset/limit pagination with composite index:**
```elixir
def list_posts(page \\ 1, per_page \\ 20) do
  offset = (page - 1) * per_page

  Post
  |> order_by(desc: :inserted_at)
  |> offset(^offset)
  |> limit(^per_page)
  |> Repo.all()
end
```

---

## Common Pitfalls

| ❌ Wrong | ✅ Correct |
|----------|-----------|
| `Repo` in LiveViews or controllers | Delegate to context modules |
| Repo.get! / Repo.insert! in application code | Use non-bang with pattern matching |
| String interpolation in `fragment` | Use parameterized `^` queries |
| N+1 from accessing associations in loops | Preload before iteration |
| Multiple Repo calls without transaction | Use `Ecto.Multi` |
| Missing indexes on foreign keys | `create index(:table, [:fk_column])` |
| Schema change + backfill in one migration | Two separate migrations |
| Irreversible `up` without `down` | Use `change/0` instead |

---

## Integration

| Predecessor | This Skill | Successor |
|-------------|------------|-----------|
| ecto-essentials | apply-ecto-conventions | code-quality |
| ecto-changeset-patterns | apply-ecto-conventions | testing-essentials |

**Companion skills:**
- `ecto-essentials` — full Ecto reference (schemas, queries, migrations)
- `ecto-changeset-patterns` — advanced validations and changeset composition
- `ecto-nested-associations` — `cast_assoc`, `Ecto.Multi`, cascade operations