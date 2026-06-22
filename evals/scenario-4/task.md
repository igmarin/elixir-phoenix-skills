# Order Management Dashboard

## Problem Description

A growing e-commerce company has asked you to build an order management feature for their Phoenix application. The operations team needs a live dashboard where staff can view all customer orders, filter them by fulfillment status, and mark individual orders as shipped—all without page refreshes.

The application already has a `Customer` schema (with `:name` and `:email` fields) and a Postgres database set up via Ecto. Your job is to add the `Order` domain: define the schema and business logic, then wire up a Phoenix LiveView that gives the ops team the real-time UI they need.

Each order should track its status (e.g., `"pending"`, `"processing"`, `"shipped"`, `"cancelled"`), a total amount, and which customer placed it. The dashboard should display orders alongside the customer name, support filtering the list by status, and let a staff member click a button to mark any order as shipped.

## Output Specification

Produce the following Elixir source files (create any intermediate directories as needed):

- `lib/my_app/orders/order.ex` — the Ecto schema for an order, including its changeset
- `lib/my_app/orders.ex` — the Orders context module with functions for listing, fetching, updating, and (optionally) creating orders
- `lib/my_app_web/live/order_dashboard_live.ex` — the Phoenix LiveView that renders the dashboard, handles the status filter, and processes the "mark as shipped" action

The files should be complete, self-contained Elixir modules that a developer could drop into a standard Phoenix 1.7 application. You do not need to generate migrations or templates—just the three `.ex` source files.
