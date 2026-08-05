---
allowed-tools: Bash(/usr/bin/code:*)
description: Open the current worktree (or a given path) in VS Code
argument-hint: [path]
---

!`T="$ARGUMENTS"; [ -n "$T" ] || T="$PWD"; T="$(cd "$T" && pwd)" || exit 1; /usr/bin/code -n "$T" >/dev/null 2>&1 & disown; echo "opened: $T"`

Report only the `opened:` line above. Do nothing else.
