---
description: Database and migration conventions
paths: ["**/*.sql", "**/db/migrate/**", "**/db/schema.rb"]
---

- Generate migrations via Rails generators — no manual timestamps
- Indexes use `algorithm: :concurrently` with `disable_ddl_transaction!`
- Include `if_not_exists` / `if_exists` guards
- Reversible migrations (use `change` or explicit `up`/`down`)
- No data migrations mixed with schema migrations
- Index all foreign keys
- Never `SELECT *` in application code
- Use `EXPLAIN (ANALYZE, BUFFERS)` to verify query plans
- Batch writes with `insert_all` / `upsert_all`
- Monitor with `pg_stat_statements` for slow queries
