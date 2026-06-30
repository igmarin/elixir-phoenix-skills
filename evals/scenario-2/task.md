# Add a Caching Layer to the User Accounts Context

## Problem Description

The platform team has identified that the `MyApp.Accounts.get_user/1` function is called hundreds of times per request cycle — from authorization checks, activity feeds, and notification rendering — all hitting Postgres directly. Under normal load this isn't a problem, but traffic spikes are causing read replica lag and slowing the request pipeline measurably.

The solution is a Cachex-based caching layer that wraps `get_user/1`: on a cache hit the user record is returned immediately; on a miss, the database is queried, the result is stored in the cache, and subsequent callers get the cached value. The cache must also be invalidated when a user record changes, so `update_user/2` should remove the stale entry.

The engineering lead has two additional concerns. First, the team needs to be able to measure whether the cache is actually helping (hit rate, miss rate) before deciding to roll it out. Second, long-lived stale data is a support headache — any cached entry should expire on its own after a reasonable interval so that even in edge cases where invalidation is missed, the data eventually refreshes.

The starter code for the project is in the `inputs/` directory. You do not need to run or compile the project.

## Output Specification

Produce the following files (you may modify existing files or add new ones as you see fit):

- An updated or new Elixir source file implementing the caching logic for `get_user/1` and `update_user/2`
- An updated `lib/my_app/application.ex` that starts Cachex as part of the application
- An updated `mix.exs` with the Cachex dependency added
- A `DESIGN.md` explaining: the TTL value you chose and why, and how to read the cache stats

All output files should be written to the working directory. You do not need to run `mix deps.get` or compile the project.
