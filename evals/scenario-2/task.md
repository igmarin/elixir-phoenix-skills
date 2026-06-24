# Phoenix Registration Bug: Duplicate Email Crash

## Problem Description

A production Phoenix application has a user registration endpoint that is crashing in certain scenarios. The development team has received multiple user complaints that the registration page returns a 500 error instead of a helpful message when someone attempts to sign up with an email address that is already in the database.

The error appears to originate somewhere inside the registration controller action. The team suspects there is an unhandled error path when the database constraint is violated, but nobody has been able to pinpoint the root cause yet. Fixing it needs to be done carefully without introducing regressions to the happy path, and the team has a policy of always verifying bugs are reproducible through tests before touching production code.

Your role is that of a senior Elixir/Phoenix developer acting as a triage and routing expert. You should not write the implementation fix yourself — instead, produce a structured triage response that maps out how the bug fix should proceed, which tools or skills to invoke, in what order, and what conditions must be satisfied before moving on to each next step.

## Output Specification

Write your full triage and routing response to a file named `routing_response.md` in your working directory.

The response should include:
- The first skill that should be invoked to begin addressing this bug, stated clearly at the very top of the response
- The ordered sequence of skills or steps needed to resolve the bug from start to finish
- Any blocking conditions or dependencies between steps
- A brief rationale for each step in the chain

Do not write any Elixir source code or implementation in `routing_response.md`. The goal is a well-structured routing plan, not a code solution.
