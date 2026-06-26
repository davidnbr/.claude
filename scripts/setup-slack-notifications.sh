#!/usr/bin/env bash
#
# setup-slack-notifications.sh
#
# Reproduces the Claude Code -> Slack notification setup:
#   1. ~/.claude/hooks/slack-notify.sh        (the webhook sender, enriched)
#   2. ~/.claude/.omc-config.json             (webhook URL + OMC dispatch off)
#   3. ~/.claude/settings.json                (native Stop/Notification -> Slack,
#                                              token lock-out + sandbox keystone)
#
# Properties:
#   - Idempotent : re-running converges to the same state (no duplicate deny
#                  rules, hooks set by assignment, not append).
#   - Atomic     : every file is written via `tmp && mv` (atomic rename); a jq
#                  failure leaves the original untouched.
#   - Consistent : only the specific keys below are changed; all other config
#                  in each file is preserved. A timestamped .bak is made first.
#
# Secret handling: the webhook URL is read from $SLACK_WEBHOOK_URL, else
# prompted (hidden). Leaving it blank keeps any existing URL in the config.
#
# Usage:
#   SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...' bash setup-slack-notifications.sh
#   # or just: bash setup-slack-notifications.sh   (it will prompt)
#
set -euo pipefail

command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || echo "WARN: curl not found — notifications will no-op until installed" >&2

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOK="$CLAUDE_DIR/hooks/slack-notify.sh"
OMC_CFG="$CLAUDE_DIR/.omc-config.json"
SETTINGS="$CLAUDE_DIR/settings.json"
STAMP="$(date +%Y%m%d-%H%M%S)"

backup() { [ -f "$1" ] && cp -p "$1" "$1.bak.$STAMP" && echo "  backup: $1.bak.$STAMP"; }
write_atomic() { # write_atomic <file> < content_on_stdin
  local f="$1" tmp; tmp="$(mktemp "${f}.XXXXXX")"
  cat > "$tmp" && mv -f "$tmp" "$f"
}
jq_atomic() { # jq_atomic <file> <jq-program> [jq-args...]
  local f="$1"; shift
  local prog="$1"; shift
  local tmp; tmp="$(mktemp "${f}.XXXXXX")"
  [ -f "$f" ] || echo '{}' > "$f"
  if jq "$@" "$prog" "$f" > "$tmp"; then mv -f "$tmp" "$f"; else rm -f "$tmp"; echo "ERROR: jq failed on $f" >&2; exit 1; fi
}

echo "==> 1/3  sender script: $HOOK"
mkdir -p "$(dirname "$HOOK")"
backup "$HOOK"
write_atomic "$HOOK" <<'SCRIPT'
#!/usr/bin/env bash
# Slack notifier for Claude Code hooks. Usage: slack-notify.sh "label"
# Enriches from hook stdin (session/cwd/reason) + transcript (ai-title/mode).
set -uo pipefail
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.omc-config.json"
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
SCRIPT
chmod +x "$HOOK"

echo "==> 2/3  webhook config: $OMC_CFG"
if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
  URL="$SLACK_WEBHOOK_URL"
else
  read -rsp 'Slack webhook URL (blank = keep existing): ' URL; echo
fi
backup "$OMC_CFG"
jq_atomic "$OMC_CFG" '
  .notifications        = (.notifications // {}) |
  .notifications.enabled = false |
  .notifications.slack  = (.notifications.slack // {}) |
  .notifications.slack.enabled = true |
  (if ($u | length) > 0 then .notifications.slack.webhookUrl = $u else . end)
' --arg u "$URL"
chmod 600 "$OMC_CFG"

echo "==> 3/3  hooks + lock-out: $SETTINGS"
ADDS=$(jq -n --arg abs "$CLAUDE_DIR/.omc-config.json" '[
  "Read(~/.claude/.omc-config.json)",
  ("Read(" + $abs + ")"),
  ("Edit(" + $abs + ")"),
  ("Write(" + $abs + ")"),
  "Bash(*omc-config.json*)",
  "Bash(*.omc-config*)"
]')
backup "$SETTINGS"
jq_atomic "$SETTINGS" '
  .hooks = (.hooks // {}) |
  .hooks.Stop         = [ { "hooks": [ { "type":"command", "command":"$HOME/.claude/hooks/slack-notify.sh \"✅ Finished\"" } ] } ] |
  .hooks.Notification = [ { "hooks": [ { "type":"command", "command":"$HOME/.claude/hooks/slack-notify.sh \"🔔 Action needed\"" } ] } ] |
  del(.hooks.SubagentStop) |
  .permissions      = (.permissions // {}) |
  .permissions.deny = (.permissions.deny // []) |
  reduce $adds[] as $x (.; if (.permissions.deny | index($x)) then . else .permissions.deny += [$x] end) |
  .sandbox = (.sandbox // {}) |
  .sandbox.allowUnsandboxedCommands = false |
  .skipDangerousModePermissionPrompt = false
' --argjson adds "$ADDS"

echo
echo "Done. Restart Claude Code for settings.json hook changes to take effect."
echo "  Stop         -> slack-notify.sh \"✅ Finished\""
echo "  Notification -> slack-notify.sh \"🔔 Action needed\""
echo "  SubagentStop -> removed"
echo "  OMC dispatch -> disabled (notifications.enabled=false); slack platform kept enabled"
echo "  token        -> locked from the agent (deny rules + allowUnsandboxedCommands=false)"
