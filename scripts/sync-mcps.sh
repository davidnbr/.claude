#!/usr/bin/env bash
# Sync user-scope MCP servers from ~/.claude/.mcp.json into ~/.claude.json
# (the only file Claude Code actually reads for --scope user servers).
set -euo pipefail

SRC="${HOME}/.claude/.mcp.json"

jq -c '.mcpServers | to_entries[]' "$SRC" | while read -r entry; do
  name=$(jq -r '.key' <<<"$entry")
  conf=$(jq -c '.value | if has("type") then . elif has("url") then .type="http" else .type="stdio" end' <<<"$entry")

  echo "==> $name"
  claude mcp remove "$name" --scope user >/dev/null 2>&1 || true
  claude mcp add-json "$name" "$conf" --scope user
done
