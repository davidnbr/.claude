---
description: Database and migration conventions
paths: ["**/*.sql", "**/db/migrate/**", "**/db/schema.rb"]
---

Migrations (Rails):
- Generate via Rails generators — no manual timestamps
- Zero-downtime safe: indexes with `algorithm: :concurrently` + `disable_ddl_transaction!`; consider `strong_migrations` to enforce
- Include `if_not_exists` / `if_exists` guards
- Reversible (use `change` or explicit `up`/`down`)
- No data migrations mixed with schema migrations; backfill in batches, separately
- Adding NOT NULL / default to large tables: split into add → backfill → validate steps

Schema & queries (PostgreSQL):
- Index all foreign keys; composite indexes ordered by selectivity/query pattern
- Never `SELECT *` in application code
- Parameterized queries only — no string-interpolated SQL
- `EXPLAIN (ANALYZE, BUFFERS)` to verify plans on non-trivial queries
- Batch writes with `insert_all` / `upsert_all`; wrap multi-step writes in transactions
- Prefer `timestamptz` over `timestamp`; `text` + check constraint over `varchar(n)` unless length is a real rule
- Monitor with `pg_stat_statements` for slow queries
