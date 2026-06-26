#!/usr/bin/env bash
# Slack notifier for Claude Code hooks. Usage: slack-notify.sh "label"
# Enriches from hook stdin (session/cwd/reason) + transcript (ai-title/mode).
set -uo pipefail
CFG="$HOME/.claude/.omc-config.json"
[ -f "$CFG" ] || exit 0
command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 || exit 0
URL=$(jq -r '.notifications.slack.webhookUrl // empty' "$CFG" 2>/dev/null)
EN=$(jq  -r '.notifications.slack.enabled // false' "$CFG" 2>/dev/null)
[ "$EN" = "true" ] && [ -n "$URL" ] || exit 0

LABEL="${1:-Claude event}"
SESS=""; PROJ=""; REASON=""; TITLE=""; MODE=""; TPATH=""; CWD=""
if [ ! -t 0 ]; then
  RAW=$(cat 2>/dev/null || true)
  if [ -n "$RAW" ]; then
    SESS=$(printf  '%s' "$RAW" | jq -r '.session_id // empty'      2>/dev/null || true)
    CWD=$(printf   '%s' "$RAW" | jq -r '.cwd // empty'             2>/dev/null || true)
    REASON=$(printf '%s' "$RAW"| jq -r '.message // empty'         2>/dev/null || true)
    TPATH=$(printf '%s' "$RAW" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    [ -n "$CWD" ] && PROJ=$(basename "$CWD")
  fi
fi
if [ -n "$TPATH" ] && [ -f "$TPATH" ]; then
  TITLE=$(jq -r 'select(.type=="ai-title").aiTitle // empty' "$TPATH" 2>/dev/null | tail -1)
  MODE=$(jq  -r 'select(.type=="mode").mode // empty'        "$TPATH" 2>/dev/null | tail -1)
fi

MSG="$LABEL"
[ -n "$REASON" ] && MSG="$MSG — $REASON"
[ -n "$TITLE" ]  && MSG="$MSG — $TITLE"
META=""
[ -n "$PROJ" ] && META="$META  ·  📁 $PROJ"
[ -n "$MODE" ] && [ "$MODE" != "normal" ] && META="$META  ·  ⚙️ $MODE"
[ -n "$SESS" ] && META="$META  ·  🔖 ${SESS:0:8}"
MSG="$MSG$META"

curl -s -m 5 -X POST "$URL" -H "Content-Type: application/json" \
  --data "$(jq -nc --arg t "$MSG" '{text:$t}')" >/dev/null 2>&1 || true
exit 0
