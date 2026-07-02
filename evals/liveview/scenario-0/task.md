# Liveview Task

## Problem

An Elixir/Phoenix team needs help with a task in this area:

Orchestrates LiveView feature development with hard gates: define mount/3 contract and assigns shape → write failing LiveView test using live_isolated or live/2 → implement mount, handle_event, and render with streams for collections → verify full LiveView lifecycle (mount→render→event→update) → quality gate (no assigns bloat, streams for >10 items, bracket access in templates); phases context→test design→implementation→quality.

The team has asked for a concise implementation artifact that a reviewer can inspect without needing to observe the agent's process.

## Output

Create `answer.md` with:

- a short plan for the work
- the concrete Elixir/Phoenix-oriented artifact or recommendation
- the verification steps or quality gates that should be run
- any assumptions that affect the result
