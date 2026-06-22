# Build the Catalog Context for ShopFlow

## Problem/Feature Description

ShopFlow is a growing e-commerce platform built with Phoenix and Ecto. The engineering team is expanding the product management subsystem and needs a proper `Catalog` context module implemented from scratch. Currently, product data is queried ad-hoc from various places in the codebase, making it difficult to maintain and prone to performance issues as the product catalog grows.

Your task is to implement the core `Catalog` context, which will serve as the single authoritative interface for product data in the application. The context needs to support a `Product` entity (each product belongs to a `Category`), including full changeset validation. The product listing function must support optional filters — users can filter by category, search by product name, and restrict results to products above a minimum price — and the returned products should have their category data readily available for display.

Write the context and schema modules as plain Elixir source files (no running database required). Also include a short `DESIGN_NOTES.md` explaining your approach to loading category data alongside products and how you handle the dynamic filter combinations.

## Output Specification

Produce the following files:

- `lib/my_app/catalog/category.ex` — Ecto schema for `Category` (has many products)
- `lib/my_app/catalog/product.ex` — Ecto schema for `Product` (belongs to a category), with a `changeset/2` function
- `lib/my_app/catalog.ex` — the `Catalog` context module with at minimum a `list_products/1` function accepting optional filters (`:category_id`, `:name`, `:min_price`)
- `DESIGN_NOTES.md` — a short explanation of your approach to efficiently loading associated category data and how the filtering logic is structured

Do not include a database migration or any runtime configuration — source files only.
