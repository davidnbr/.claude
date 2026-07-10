#!/usr/bin/env bash
# Stop-hook gate for slack-notify.sh: only notify when the session is
# genuinely done — not on intermediate stops or while background work
# (subagents, teammates, shells, workflows, crons) is still running.
# Reads the Stop hook JSON from stdin, then forwards it to slack-notify.sh.
set -uo pipefail
have() { command -v "$1" >/dev/null 2>&1; }

RAW=""
[ -t 0 ] || RAW=$(cat 2>/dev/null || true)

LOG="$HOME/.claude/hooks/stop-notify.log"
logline() { printf '%s %s\n' "$(date '+%F %T')" "$1" >>"$LOG" 2>/dev/null || true; }

if [ -n "$RAW" ] && have jq; then
  SID=$(printf '%s' "$RAW" | jq -r '.session_id // "?" | .[0:8]' 2>/dev/null || echo '?')
  # Skip sessions spawned as agents (subagents/teammates/reviewers): their
  # transcript "agent-setting" record names a specific agent type, while
  # user sessions and background jobs record agentSetting "claude".
  TPATH=$(printf '%s' "$RAW" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  if [ -n "$TPATH" ] && [ -f "$TPATH" ]; then
    AGENT=$(head -5 "$TPATH" 2>/dev/null | jq -r 'select(.type=="agent-setting") | .agentSetting' 2>/dev/null | head -1)
    if [ -n "$AGENT" ] && [ "$AGENT" != "claude" ]; then
      logline "skip sid=$SID reason=agent_session:$AGENT"; exit 0
    fi
  fi
  # Skip when this stop was itself triggered by a stop hook continuation.
  ACTIVE=$(printf '%s' "$RAW" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
  [ "$ACTIVE" = "true" ] && { logline "skip sid=$SID reason=stop_hook_active"; exit 0; }
  # Skip while background tasks (subagents/teammates/shells/etc.) still run.
  # Count only real in-flight work. Ignore persistent listeners
  # ("monitor", "MCP task" — e.g. claude-mem/OMC MCP watchers) that can
  # sit in the array indefinitely and would suppress the ping forever.
  BG=$(printf '%s' "$RAW" | jq -r '[(.background_tasks // [])[] | select(.type != "monitor" and .type != "MCP task")] | length' 2>/dev/null || echo 0)
  BGDUMP=$(printf '%s' "$RAW" | jq -c '.background_tasks // []' 2>/dev/null || echo '[]')
  [ "${BG:-0}" -gt 0 ] 2>/dev/null && { logline "skip sid=$SID reason=background_tasks:$BG tasks=$BGDUMP"; exit 0; }
  # Skip while session crons are pending (loop not really finished).
  CRONS=$(printf '%s' "$RAW" | jq -r '(.session_crons // []) | length' 2>/dev/null || echo 0)
  [ "${CRONS:-0}" -gt 0 ] 2>/dev/null && { logline "skip sid=$SID reason=session_crons:$CRONS"; exit 0; }
  logline "notify sid=$SID"
fi

printf '%s' "$RAW" | "$HOME/.claude/hooks/slack-notify.sh" "✅ Finished"
exit 0
