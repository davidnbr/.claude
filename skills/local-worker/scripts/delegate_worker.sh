#!/usr/bin/env bash
# Dispatch a coding task to a local Ollama-backed worker (claude or opencode),
# fully separate process/session from the orchestrating Claude Code session.
# Usage: delegate_worker.sh <backend: claude|opencode> <model-tag> "<task prompt>" [--continue]
set -euo pipefail

backend="${1:?backend required: claude|opencode}"
model="${2:?model tag required, e.g. qwen2.5-coder:latest}"
prompt="${3:?task prompt required}"
continue_flag="${4:-}"

case "$backend" in
  claude)
    cmd=(env ANTHROPIC_BASE_URL=http://localhost:11434 ANTHROPIC_AUTH_TOKEN=ollama \
      claude -p "$prompt" \
      --model "$model" \
      --allowedTools "Read,Edit,Bash" \
      --permission-mode acceptEdits \
      --output-format json)
    [[ "$continue_flag" == "--continue" ]] && cmd+=(--continue)
    ;;
  opencode)
    cmd=(opencode run "$prompt" \
      --model "ollama/$model" \
      --format json \
      --dangerously-skip-permissions)
    [[ "$continue_flag" == "--continue" ]] && cmd+=(--continue)
    ;;
  *)
    echo "unknown backend: $backend (use claude or opencode)" >&2
    exit 1
    ;;
esac

"${cmd[@]}"
