---
description: Python development conventions
paths: ["**/*.py"]
---

- Python 3.12+, type hints on all function signatures
- PEP 8 style, PEP 257 docstrings
- Async/await for I/O operations
- Specific exceptions — never bare `except:`
- pytest with fixtures, >80% coverage target
- Use `ruff` for linting, `mypy` for type checking
- Environment variables for secrets (never hardcoded)
- Parameterized queries for database access
