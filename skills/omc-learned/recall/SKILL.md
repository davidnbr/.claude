---
name: recall
description: Spaced repetition learning system for developers using multiple AI tools. Capture → process → quiz across Cursor, Copilot, and Claude Code sessions.
triggers:
  - /recall
  - recall review
  - recall inbox
  - recall stats
  - recall add
  - recall all
  - spaced repetition
  - quiz me
---

# Recall — Spaced Repetition Skill

Multi-layer SR system spanning Cursor, Copilot, and Claude Code projects.

## Files
- `~/.learning/inbox.md` — raw capture from any tool
- `~/.learning/deck.json` — structured SR deck with scheduling metadata

## Commands

| Invocation | Action |
|-----------|--------|
| `/recall` | Review due cards (interactive quiz) |
| `/recall all` | Review ALL cards regardless of due date |
| `/recall inbox` | Process inbox.md into deck.json |
| `/recall add "concept" [--project tag]` | Add single card directly |
| `/recall stats` | Deck stats, streak, due count |

---

## Layer 1 — Shell Setup (run once)

When user first runs this skill, check if `learn` function exists in shell config. If not, add it.

```bash
# Detect shell config file
SHELL_RC="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && SHELL_RC="$HOME/.bashrc"

# Check if already installed
grep -q "function learn()" "$SHELL_RC" 2>/dev/null || cat >> "$SHELL_RC" << 'EOF'

# Spaced repetition capture — feeds ~/.learning/inbox.md
function learn() {
  local concept="$*"
  local date=$(date +%Y-%m-%d)
  local project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "general")
  mkdir -p ~/.learning
  echo "[$date] [project:$project] $concept" >> ~/.learning/inbox.md
  echo "Captured: $concept (project: $project)"
}
EOF
```

Tell user: `source ~/.zshrc` (or bashrc) to activate the `learn` command.

---

## Layer 2 — Process Inbox → Deck

When `/recall inbox` is invoked:

1. Read `~/.learning/inbox.md`
2. Read existing `~/.learning/deck.json` (or init empty array)
3. For each line in inbox not already in deck (match by concept text):
   - Parse: `[date] [project:tag] concept text`
   - Create card:
     ```json
     {
       "id": "<uuid-style: timestamp+index>",
       "concept": "<concept text>",
       "project": "<project tag>",
       "created": "<date>",
       "last_reviewed": null,
       "next_review": "<created date>",
       "interval_days": 1,
       "ease_factor": 2.5,
       "history": []
     }
     ```
4. Write updated deck to `~/.learning/deck.json`
5. Report: "Processed X new cards. Deck now has Y total cards."
6. Clear processed lines from inbox (or mark with ✓ prefix)

---

## Layer 3 — FSRS-like Scheduling

After each card review, user rates recall 1–5:

| Rating | Meaning | Interval update |
|--------|---------|-----------------|
| 1 | Blackout — no recall | Reset to 1 day |
| 2 | Wrong but familiar | Reset to 1 day |
| 3 | Recalled with effort | Keep same interval |
| 4 | Recalled correctly | `interval * ease_factor` |
| 5 | Perfect recall | `interval * ease_factor * 1.3` |

After update:
- `next_review = today + new_interval_days`
- `last_reviewed = today`
- Append `{date, rating}` to `history[]`
- If rating >= 4 and ease_factor < 2.5: `ease_factor += 0.1`
- If rating < 3 and ease_factor > 1.3: `ease_factor -= 0.2`

---

## Layer 4 — Interactive Quiz Flow

When `/recall` or `/recall all` is invoked:

1. Load deck, filter `next_review <= today` (or all for `/recall all`)
2. If 0 due: show "No cards due. Next review: [date of nearest card]." Stop.
3. Shuffle due cards
4. For each card:
   ```
   ─────────────────────────────
   Card [X/Y] | Project: [tag]
   ─────────────────────────────
   CONCEPT: [concept text]

   Try to recall everything you know about this.
   Press Enter when ready to see context...
   ```
5. After Enter:
   ```
   ORIGINAL CONTEXT:
   [concept text — show full, with any detail stored]

   How well did you recall? Rate 1-5:
   1=blackout  2=wrong  3=effortful  4=correct  5=perfect
   ```
6. Read rating, update card, continue
7. After all cards:
   ```
   ─── Session Complete ───
   Reviewed: X cards
   Due tomorrow: Y
   Next session: [date]
   Streak: Z days
   ```

---

## Layer 5 — Stats (`/recall stats`)

Display:
```
~/.learning/deck.json stats
───────────────────────────
Total cards:     X
Due today:       Y
Due this week:   Z
Last reviewed:   [date]
Current streak:  N days

By project:
  WG:       X cards
  general:  Y cards
  ...
```

Streak = consecutive days with at least 1 review session completed.

---

## Auto-extract from Claude Code Conversation

When `/recall` invoked at end of session, or user says "capture learnings" / "extract learnings" / "save what I learned":

1. Scan current conversation for learning signals:
   - New concepts explained by AI
   - Error root causes diagnosed
   - Patterns/approaches chosen + why
   - Commands/APIs/flags user didn't know before
   - Architecture decisions with tradeoffs

2. Generate atomic question-form card per concept:
   - Bad: "Kubernetes node failure"
   - Good: "How does K8s reschedule pods when a node fails?"

3. Show extracted list, user confirms:
   ```
   Extracted 4 learnings from this session:
   [1] How does FSRS ease_factor adjust on failed recall?
   [2] Why does home-manager overwrite manual .bashrc edits?
   [3] What does ble-attach do in bash config?
   [4] How does spaced repetition differ from massed practice?

   Keep all? (y), or enter numbers to drop (e.g. 2 4):
   ```

4. Append confirmed items to `~/.learning/inbox.md` with date + project tag
5. Report: "Saved X learnings to inbox. Run `/recall inbox` to process into deck."

---

## First-Run Checklist

When skill invoked for first time (deck.json missing):

1. Install `learn` shell function (Layer 1)
2. Create `~/.learning/inbox.md` (empty)
3. Create `~/.learning/deck.json` as `[]`
4. Show quick-start:
   ```
   Recall installed.

   Capture from any tool:  learn "what you just understood"
   Process inbox:          /recall inbox
   Review due cards:       /recall
   Add directly:           /recall add "concept" --project myapp
   ```

---

## Pitfalls

- Deck grows fast. Review every day or due count compounds painfully.
- Cards must be atomic — one concept per card. Reject multi-concept entries at inbox processing, split them.
- `learn` alias needs `git` available to auto-detect project. Falls back to "general" if not in git repo.
- Card text should be the question, not just a label. Bad: "Kubernetes". Good: "How does K8s handle pod rescheduling when a node fails?"
- Cursor/Copilot sessions: no auto-capture. Must run `learn "..."` manually in terminal after session ends.
