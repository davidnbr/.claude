#!/usr/bin/env bash
# Notifier for Claude Code hooks. Usage: slack-notify.sh "label"
# Builds an enriched message (session/cwd/reason + transcript ai-title/mode),
# then routes it: Slack webhook when configured+enabled, else desktop
# (osascript on macOS, notify-send on Linux). Always exits 0.
set -uo pipefail
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.omc-config.json"
have() { command -v "$1" >/dev/null 2>&1; }

# --- build message (transport-independent) ---
LABEL="${1:-Claude event}"
SESS=""; PROJ=""; REASON=""; TITLE=""; MODE=""; TPATH=""; CWD=""
if [ ! -t 0 ]; then
  RAW=$(cat 2>/dev/null || true)
  if [ -n "$RAW" ] && have jq; then
    SESS=$(printf  '%s' "$RAW" | jq -r '.session_id // empty'      2>/dev/null || true)
    CWD=$(printf   '%s' "$RAW" | jq -r '.cwd // empty'             2>/dev/null || true)
    REASON=$(printf '%s' "$RAW"| jq -r '.message // empty'         2>/dev/null || true)
    TPATH=$(printf '%s' "$RAW" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    [ -n "$CWD" ] && PROJ=$(basename "$CWD")
  fi
fi
if [ -n "$TPATH" ] && [ -f "$TPATH" ] && have jq; then
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

# --- transport: Slack if configured, else desktop fallback ---
URL=""; EN="false"
if [ -f "$CFG" ] && have jq; then
  URL=$(jq -r '.notifications.slack.webhookUrl // empty' "$CFG" 2>/dev/null || true)
  EN=$(jq  -r '.notifications.slack.enabled // false'    "$CFG" 2>/dev/null || true)
fi

if [ "$EN" = "true" ] && [ -n "$URL" ] && have curl; then
  curl -s -m 5 -X POST "$URL" -H "Content-Type: application/json" \
    --data "$(jq -nc --arg t "$MSG" '{text:$t}')" >/dev/null 2>&1 || true
elif have notify-send; then
  # Linux desktop (Ubuntu/GNOME via libnotify-bin)
  notify-send "Claude Code" "$MSG" >/dev/null 2>&1 || true
elif have osascript; then
  # macOS fallback (AppleScript) — absent on Linux, skipped there
  OMC_MSG="$MSG" osascript -e 'display notification (system attribute "OMC_MSG") with title "Claude Code"' >/dev/null 2>&1 || true
fi
exit 0
