---
description: Ruby and Rails conventions
paths: ["**/*.rb"]
---

- Ruby 3.x+, frozen string literals
- Guard clauses and early returns over nested conditionals
- `&.` (safe navigation) over `try`
- Predicate methods end with `?`, destructive with `!`
- Thin controllers — logic in service objects or models
- Strong parameters on every action accepting input
- `includes`/`preload`/`eager_load` to prevent N+1
- `find_each` / `find_in_batches` for large datasets
- RSpec: `describe` for classes, `context` for conditions (start with "when")
- Prefer `instance_double` over generic `double`
- Minimize mocks — use real objects when practical
