---
description: Ruby and Rails conventions
paths: ["**/*.rb"]
---

- Ruby 3.x+, `# frozen_string_literal: true` in every file
- RuboCop (with rubocop-rails / rubocop-rspec where relevant) — follow project's `.rubocop.yml`
- Guard clauses and early returns over nested conditionals
- `&.` (safe navigation) over `try`; avoid `rescue nil`
- Predicate methods end with `?`; destructive/surprising variants with `!`
- Thin controllers — business logic in service objects or models; no logic in views
- Strong parameters on every action accepting input
- `includes`/`preload`/`eager_load` to prevent N+1 (verify with `bullet` in dev)
- `find_each` / `find_in_batches` for large datasets; `insert_all`/`upsert_all` for bulk writes
- Scopes for reusable query fragments; no raw SQL string interpolation — use placeholders
- RSpec: `describe` for classes/methods, `context` for conditions (start with "when"); one behavior per example
- Prefer `instance_double`/`class_double` (verifying doubles) over generic `double`; minimize mocks — use real objects when practical
- FactoryBot factories over fixtures; `build`/`build_stubbed` over `create` when DB not needed
