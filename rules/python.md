---
description: Python development conventions
paths: ["**/*.py"]
---

- Python 3.12+; type hints on all public function signatures (PEP 484), modern syntax (`X | None`, builtin generics `list[str]`)
- PEP 8 style, PEP 257 docstrings on public modules/classes/functions
- Match project's existing toolchain first; for new projects default to `uv` (env/deps), `ruff` (lint + format), `mypy` (types), config in `pyproject.toml`
- Specific exceptions — never bare `except:`; never swallow exceptions silently
- `async`/`await` for I/O-bound work; never block the event loop with sync I/O
- `pathlib.Path` over `os.path`; f-strings over `%`/`.format()`
- Dataclasses or Pydantic for structured data — not raw dicts across boundaries
- pytest with fixtures and parametrize; >80% coverage target; factories over fixtures-with-baked-data for models
- Environment variables for secrets (never hardcoded); parameterized queries for all database access
- Pin dependencies via lockfile (`uv.lock` / `requirements.txt` compiled)
