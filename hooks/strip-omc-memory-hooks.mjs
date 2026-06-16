#!/usr/bin/env node
/**
 * strip-omc-memory-hooks.mjs
 *
 * Removes OMC's wiki + project-memory hook registrations from the live
 * oh-my-claudecode plugin cache so they stop injecting context / writing
 * .omc/ files. Survives plugin updates: re-applies on every SessionStart
 * against whatever version dir is currently installed.
 *
 * Idempotent. Fail-open (never blocks the session). Patches every installed
 * version under the cache. Backs up each hooks.json once (.orig) before first
 * edit so the original is recoverable.
 *
 * Pairs with `OMC_DISABLE_TOOLS=wiki,memory` in settings.json (that drops the
 * MCP tools; this drops the hooks). Together = full removal, no claude-mem dup.
 *
 * To re-enable: delete this script + its SessionStart hook entry, then restore
 * each `hooks.json.orig`, or just reinstall the plugin.
 */
import {
  readFileSync,
  writeFileSync,
  existsSync,
  readdirSync,
  copyFileSync,
} from "fs";
import { join } from "path";
import { homedir } from "os";

// Hook scripts to strip (matched as substrings of the command string).
const STRIP_SCRIPTS = [
  "project-memory-session.mjs",
  "project-memory-posttool.mjs",
  "project-memory-precompact.mjs",
  "wiki-session-start.mjs",
  "wiki-pre-compact.mjs",
  "wiki-session-end.mjs",
];

function ok() {
  process.stdout.write(
    JSON.stringify({ continue: true, suppressOutput: true }),
  );
}

function shouldStrip(command) {
  return (
    typeof command === "string" &&
    STRIP_SCRIPTS.some((s) => command.includes(s))
  );
}

/** Returns true if the hooks object was modified. */
function stripHooks(hooksObj) {
  if (!hooksObj || typeof hooksObj !== "object") return false;
  let changed = false;

  for (const eventName of Object.keys(hooksObj)) {
    const entries = hooksObj[eventName];
    if (!Array.isArray(entries)) continue;

    const keptEntries = [];
    for (const entry of entries) {
      const inner = Array.isArray(entry?.hooks) ? entry.hooks : [];
      const keptInner = inner.filter((h) => !shouldStrip(h?.command));
      if (keptInner.length !== inner.length) changed = true;

      // Drop matcher entries whose hook list is now empty; keep others.
      if (keptInner.length > 0) {
        keptEntries.push({ ...entry, hooks: keptInner });
      } else if (inner.length === 0) {
        keptEntries.push(entry); // entry had no hooks to begin with; leave as-is
      }
    }

    if (keptEntries.length > 0) {
      hooksObj[eventName] = keptEntries;
    } else {
      delete hooksObj[eventName];
      changed = true;
    }
  }

  return changed;
}

function patchFile(hooksPath) {
  let raw;
  try {
    raw = readFileSync(hooksPath, "utf-8");
  } catch {
    return;
  }

  let json;
  try {
    json = JSON.parse(raw);
  } catch {
    return; // malformed; leave untouched
  }

  if (!stripHooks(json?.hooks)) return; // already clean — idempotent no-op

  // One-time backup of the pristine file.
  const backup = hooksPath + ".orig";
  if (!existsSync(backup)) {
    try {
      copyFileSync(hooksPath, backup);
    } catch {}
  }

  try {
    writeFileSync(hooksPath, JSON.stringify(json, null, 2) + "\n", "utf-8");
  } catch {}
}

function main() {
  try {
    const base = join(
      process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude"),
      "plugins",
      "cache",
      "omc",
      "oh-my-claudecode",
    );
    if (!existsSync(base)) return ok();

    for (const versionDir of readdirSync(base)) {
      const hooksPath = join(base, versionDir, "hooks", "hooks.json");
      if (existsSync(hooksPath)) patchFile(hooksPath);
    }
  } catch {
    // fail-open
  }
  ok();
}

main();
