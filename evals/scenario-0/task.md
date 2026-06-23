# Real-Time Order Dashboard with Threshold Alerts

## Problem/Feature Description

Your team is building a Phoenix e-commerce platform. The product owner has raised a new ticket with three interconnected requirements: first, the operations dashboard should gain a live widget that displays the current total order count and updates in real time as new orders come in; second, orders need to be persisted to a database table that can be queried for analytics; and third, whenever the order count crosses 100 the system should automatically send an email alert to the admin team.

The engineering lead wants a clear breakdown of how to approach this before any code is written. The concern is that this ticket touches multiple parts of the stack — the LiveView front-end, the Ecto data layer, and an email integration — and it is easy for the work to get tangled if not properly sequenced. You have been asked to analyse the request, identify the distinct technical concerns, determine the right order to tackle them, and document a concrete plan that the development team can follow.

## Output Specification

Write your full triage and routing plan to a file called `routing_response.md`. The file should cover:

- An ordered list of the technical sub-tasks the team needs to complete, each mapped to the appropriate area of the stack
- The recommended sequence in which to tackle the sub-tasks and the reasoning behind that order
- Any dependencies between sub-tasks (e.g. which steps must be finished before others can start)

The goal at this stage is a clear, actionable plan that the team can hand to developers as a brief — focus on the planning document, not on producing code.
