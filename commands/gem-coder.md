---
name: gem-coder
description: "Orchestrates Google Gemini to write or edit code. Handles the 'Draft -> Review -> Fix' loop."
---

# Gemini Coding Agent

This skill allows you (Claude) to act as a **Principal Architect** who delegates implementation details to a **Junior AI (Gemini)**.

## Usage

Trigger this when the user asks to "code", "fix", "refactor", or "edit" files.

## Workflow

### Step 1: CONTEXTUALIZE & EXECUTE

Decide if this is a **New File** or an **Edit**.

**Option A: Creating a New File**
If creating from scratch, run:
`gemini -c "$USER_PROMPT. Output valid code only." > .gemini_draft.tmp`

**Option B: Editing/Refactoring Existing Files**
If modifying files (e.g., `main.py`), you **MUST** provide the file context. Run:
`cat "$TARGET_FILE" | gemini -c "Here is the current code in stdin. $USER_PROMPT. Output the FULL modified file code only." > .gemini_draft.tmp`

### Step 2: READ

Read the content of `.gemini_draft.tmp`.

### Step 3: REVIEW (The Quality Gate)

Act as a Senior Engineer. Critique the `.gemini_draft.tmp` content.

* **Security Check:** Are there SQL injections or exposed secrets?
* **Logic Check:** Did it actually follow the instructions?
* **Context Check:** Does it fit the project structure?

### Step 4: DECIDE

* **If the code is good:**
    1. Refine minor formatting/imports yourself.
    2. Output the final code to the user (or overwrite the target file if permitted).
* **If the code is bad/incomplete:**
    1. **DO NOT FIX IT YOURSELF.**
    2. **LOOP BACK:** Run the `gemini` command again, passing the *draft* and your *critique* as the prompt:
        `cat .gemini_draft.tmp | gemini -c "The previous code had these errors: [YOUR_CRITIQUE]. Fix them and output the full code." > .gemini_draft.tmp`

### Step 5: CLEANUP

Delete `.gemini_draft.tmp`.
