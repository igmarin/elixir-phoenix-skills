# Build the Data Layer for a Project Management System

## Problem/Feature Description

Your team is building an internal project management tool for a software consultancy. Teams of engineers are organized into named groups, and each engineer (User) belongs to exactly one Team. Engineers create Projects under their account, and each Project can have multiple Tasks that get created and updated as work progresses.

The backend database doesn't exist yet — you need to design and implement the Elixir data layer from scratch. This means writing Ecto migrations to create the four tables (teams, users, projects, tasks) as well as the schema modules, changeset functions, and a context module that other parts of the application will call.

The system will eventually support a public-facing API where clients submit JSON payloads to create or update projects with their tasks in a single request. The context module must handle this correctly, ensuring that when a project's task list changes, the database reflects exactly what was submitted — no manual insertions, no orphaned rows.

The context also needs to handle project updates safely: since the application caches projects in memory before handing them to update functions, you must ensure the database state is consulted before applying changes to associated data.

## Output Specification

Write the following files to disk:

- `priv/repo/migrations/` — four migration files (one per table: teams, users, projects, tasks). Use realistic timestamps in the filenames (e.g. `20240101120000_create_teams.exs`). Each migration file should contain only the schema changes for that table.
- `lib/my_app/project_management/team.ex` — Ecto schema module for Team
- `lib/my_app/project_management/user.ex` — Ecto schema module for User (belongs to Team)
- `lib/my_app/project_management/project.ex` — Ecto schema module for Project (belongs to User, has many Tasks); changeset logic should support both the creation and update workflows
- `lib/my_app/project_management/task.ex` — Ecto schema module for Task (belongs to Project)
- `lib/my_app/project_management.ex` — context module with at minimum:
  - `create_project/1` — creates a project with tasks in a single operation
  - `update_project/2` — updates a project and its tasks
  - `get_project!/1` — fetches a project by id

Do not include a mix.exs, config files, or test files — just the migration and source files listed above.
