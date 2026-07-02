# Shared Task Board — Live Collaboration Feature

## Problem/Feature Description

The operations team at a logistics company has been requesting a shared task board that multiple dispatchers can use simultaneously. Right now, when one dispatcher creates or closes a task, others don't know about it unless they refresh the page — leading to duplicated effort and missed handoffs. The engineering manager has asked you to add real-time collaboration to the existing Phoenix application.

The application already has a basic `MyApp.Tasks` context module with the database access functions it needs, and your job is to wire up a LiveView page at `/tasks` that shows the full task list and refreshes automatically whenever any user makes a change. Dispatchers should see new tasks appear, status updates reflect, and deleted tasks disappear — all without a page reload. The UI doesn't need to be elaborate: a clean list with task title and status, plus a form to add new tasks and buttons to delete them, is sufficient.

## Output Specification

Write the following source files to disk (no running server required — the reviewer will inspect the source):

- `lib/my_app_web/live/task_live/index.ex` — the LiveView module handling the task list page
- `lib/my_app_web/live/task_live/index.html.heex` — the HEEx template for the page
- `lib/my_app/tasks.ex` — the context module with `list_tasks/0`, `create_task/1`, and `delete_task/1` functions that handle both persistence and real-time broadcasts

The context module should manage broadcasting internally so that callers (including the LiveView) never need to know about PubSub directly. The LiveView module should subscribe to updates and react to them.

Do not leave any large generated or downloaded files in the workspace — only the three source files above are expected.
